#!/home/neg/src/salt/.venv/bin/python3
"""
salt-daemon.py — pre-loaded Salt Caller daemon for faster state.apply

Runs as root. Pre-loads salt modules once, then handles state.apply
requests over a Unix socket without re-loading Python/Salt on each run.

Saves ~0.4s per run by avoiding Python import + salt module loading overhead.

Protocol (line-oriented over Unix socket):
  Client → daemon: single JSON line:
    {"state": "system_description", "kwargs": {"test": true}, "log_file": "/path/to/log"}
  Daemon → client: streaming JSON lines:
    {"type": "stdout", "line": "..."}   -- formatted salt output (summary)
    {"type": "exit",   "code": 0}       -- final exit code

Log file handling:
  - The daemon adds a FileHandler to the root logger writing to the given
    log_file path. This captures "Executing state X for [name]" debug lines
    that apply_cachyos.sh's awk watcher expects to read via `tail -f`.
  - The formatted salt output summary is written to the log file AND sent
    to the client.

Usage:
  sudo /path/to/.venv/bin/python3 scripts/salt-daemon.py
  sudo /path/to/.venv/bin/python3 scripts/salt-daemon.py --config-dir /path/to/.salt_runtime
  sudo /path/to/.venv/bin/python3 scripts/salt-daemon.py --socket /tmp/salt-daemon.sock

  Client: scripts/salt-apply.sh [state] [--test]
"""

import io
import json
import logging
import os
import signal
import socket
import sys
import threading
import warnings

# ── Salt venv path setup ─────────────────────────────────────────────────────
# Ensure the venv site-packages is on the path when run with system python3.
_SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_VENV_SITE = os.path.join(_SCRIPT_DIR, ".venv", "lib")
if os.path.isdir(_VENV_SITE):
    for _entry in sorted(os.listdir(_VENV_SITE)):
        _candidate = os.path.join(_VENV_SITE, _entry, "site-packages")
        if os.path.isdir(_candidate) and _candidate not in sys.path:
            sys.path.insert(0, _candidate)
            break

# ── Suppress Salt deprecation warnings ──────────────────────────────────────
_orig_showwarning = warnings.showwarning


def _showwarning(msg, cat, filename, lineno, file=None, line=None):
    if cat is DeprecationWarning and "/salt/" in (filename or ""):
        return
    _orig_showwarning(msg, cat, filename, lineno, file, line)


warnings.showwarning = _showwarning


# ── Patch removed stdlib modules for Python 3.13+ ───────────────────────────
class _MockCrypt:
    def __init__(self):
        try:
            import passlib.hash as _hash
            self._hash = _hash
        except ImportError:
            self._hash = None

        class Method:
            def __init__(self, name, ident):
                self.name = name
                self.ident = ident

        self.methods = [
            Method("sha512", "6"),
            Method("sha256", "5"),
            Method("md5", "1"),
            Method("crypt", ""),
        ]

    def crypt(self, word, salt):
        if not self._hash:
            raise ImportError("passlib is required for crypt emulation")
        from passlib.hash import des_crypt, md5_crypt, sha256_crypt, sha512_crypt

        if salt.startswith("$6$"):
            return sha512_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$5$"):
            return sha256_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$1$"):
            return md5_crypt.hash(word, salt=salt.split("$")[2])
        return des_crypt.hash(word, salt=salt)


sys.modules["crypt"] = _MockCrypt()


class _MockSpwd:
    def getspnam(self, name):
        raise KeyError(
            f"spwd.getspnam emulation: user {name} lookup failed or not implemented"
        )


sys.modules["spwd"] = _MockSpwd()

# ── Defaults ─────────────────────────────────────────────────────────────────
_DEFAULT_SOCKET = "/tmp/salt-daemon.sock"
_DEFAULT_CONFIG_DIR = os.path.join(_SCRIPT_DIR, ".salt_runtime")

log = logging.getLogger("salt-daemon")


# ── Salt loader ───────────────────────────────────────────────────────────────
def load_salt(config_dir: str):
    """Load Salt config, grains, and SMinion once at startup."""
    import salt.config
    import salt.loader
    import salt.minion

    config_file = os.path.join(config_dir, "minion")
    log.info("Loading salt config from %s", config_file)
    opts = salt.config.minion_config(config_file)
    opts["file_client"] = "local"
    opts["local"] = True
    opts["caller"] = True

    log.info("Loading grains...")
    opts["grains"] = salt.loader.grains(opts)

    log.info("Loading SMinion (modules, states, renderers)...")
    minion = salt.minion.SMinion(opts)

    log.info("Salt ready — %d functions loaded.", len(minion.functions))
    return opts, minion


# ── State runner ──────────────────────────────────────────────────────────────
_LOG_FMT = "%(asctime)s [%(name)-17s:%(lineno)-4d][%(levelname)-8s][%(process)d] %(message)s"


def run_state(
    opts: dict,
    minion,
    state: str,
    kwargs: dict,
    log_file: str,
    client_sock: socket.socket,
) -> int:
    """
    Execute state.sls on the pre-loaded minion and stream output to the client.

    - Adds a FileHandler to the root logger so "Executing state X for [name]"
      debug lines go to log_file (for apply_cachyos.sh's awk/tail watcher).
    - Captures stdout so salt.output.display_output writes are caught.
    - Appends formatted stdout to log_file (for the awk summary watcher).
    - Sends all output lines to client as {"type": "stdout", "line": "..."}.
    """
    import salt.output

    def send(obj: dict) -> None:
        try:
            client_sock.sendall((json.dumps(obj) + "\n").encode())
        except OSError:
            pass

    # Per-call opts (shallow copy so we don't mutate the shared opts)
    run_opts = dict(opts)
    run_opts["state_output"] = kwargs.get("state_output", "mixed_id")
    if kwargs.get("test"):
        run_opts["test"] = True

    # ── Set up file logging ──────────────────────────────────────────────────
    # We need the root logger level at DEBUG so salt's "Executing state X for [name]"
    # messages propagate through named loggers (which inherit from root).  Save and
    # restore the original level so the stderr handler stays at its configured level.
    file_handler = None
    saved_root_level = logging.root.level
    if log_file:
        try:
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
            file_handler = logging.FileHandler(log_file, mode="a", encoding="utf-8")
            file_handler.setLevel(logging.DEBUG)
            file_handler.setFormatter(logging.Formatter(_LOG_FMT))
            logging.root.addHandler(file_handler)
            # Lower root level so DEBUG records reach the file handler.
            # The stderr handler (basicConfig) retains its own level filter.
            logging.root.setLevel(logging.DEBUG)
        except OSError as exc:
            log.warning("Cannot open log file %s: %s", log_file, exc)

    # ── Run state.sls ────────────────────────────────────────────────────────
    exit_code = 0
    result = None
    try:
        result = minion.functions["state.sls"](state, **{k: v for k, v in kwargs.items() if k != "state_output"})
    except Exception as exc:
        err_msg = f"salt-daemon: error running state.sls({state!r}): {exc}"
        log.exception(err_msg)
        send({"type": "stdout", "line": err_msg})
        send({"type": "exit", "code": 1})
        return 1

    # ── Format and emit output ───────────────────────────────────────────────
    # Determine exit code from state results before formatting
    if isinstance(result, dict):
        for state_result in result.values():
            if isinstance(state_result, dict) and state_result.get("result") is False:
                exit_code = 1
                break

    # Capture display_output (which writes to sys.stdout)
    captured = io.StringIO()
    old_stdout = sys.stdout
    sys.stdout = captured
    if isinstance(result, dict):
        salt.output.display_output({"local": result}, out="highstate", opts=run_opts)
    else:
        # Non-dict result (error list, etc.)
        salt.output.display_output({"local": result}, out="nested", opts=run_opts)
    sys.stdout = old_stdout
    formatted_output = captured.getvalue()

    # Write to log file
    if log_file and formatted_output:
        try:
            with open(log_file, "a", encoding="utf-8") as f:
                f.write(formatted_output)
        except OSError as exc:
            log.warning("Cannot write output to log file %s: %s", log_file, exc)

    # Send to client
    for line in formatted_output.splitlines():
        send({"type": "stdout", "line": line})

    send({"type": "exit", "code": exit_code})

    # ── Teardown file handler ────────────────────────────────────────────────
    if file_handler is not None:
        logging.root.removeHandler(file_handler)
        file_handler.close()
    logging.root.setLevel(saved_root_level)

    return exit_code


# ── Socket server ─────────────────────────────────────────────────────────────
class DaemonServer:
    def __init__(self, socket_path: str, opts: dict, minion):
        self.socket_path = socket_path
        self.opts = opts
        self.minion = minion
        # Serialize state runs to avoid shared-state corruption
        self._lock = threading.Lock()

    def handle_client(self, conn: socket.socket) -> None:
        try:
            # Read one newline-terminated JSON line
            data = b""
            conn.settimeout(10.0)
            try:
                while b"\n" not in data:
                    chunk = conn.recv(4096)
                    if not chunk:
                        return
                    data += chunk
            except socket.timeout:
                log.warning("Client timed out during request read")
                return
            finally:
                conn.settimeout(None)

            request = json.loads(data.split(b"\n")[0].decode())
        except (json.JSONDecodeError, OSError, UnicodeDecodeError) as exc:
            log.warning("Bad client request: %s", exc)
            conn.close()
            return

        state = request.get("state", "system_description")
        kwargs = request.get("kwargs", {})
        log_file = request.get("log_file", "")

        log.info("Request: state=%r kwargs=%s log_file=%r", state, kwargs, log_file)

        with self._lock:
            try:
                run_state(self.opts, self.minion, state, kwargs, log_file, conn)
            except Exception as exc:
                log.exception("Unhandled error in run_state: %s", exc)
                try:
                    conn.sendall((json.dumps({"type": "exit", "code": 1}) + "\n").encode())
                except OSError:
                    pass

        conn.close()

    def serve(self, socket_path: str) -> None:
        if os.path.exists(socket_path):
            os.unlink(socket_path)

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        server.bind(socket_path)
        # Allow wheel group to connect so users can send requests without sudo.
        # The daemon itself still runs as root and executes privileged state ops.
        try:
            import grp
            wheel_gid = grp.getgrnam("wheel").gr_gid
            os.chown(socket_path, 0, wheel_gid)
            os.chmod(socket_path, 0o660)
        except (KeyError, OSError):
            # Fallback to root-only if wheel group doesn't exist
            os.chmod(socket_path, 0o600)
        server.listen(5)

        def _shutdown(signum, frame):
            log.info("Received signal %d, shutting down...", signum)
            server.close()
            if os.path.exists(socket_path):
                try:
                    os.unlink(socket_path)
                except OSError:
                    pass
            sys.exit(0)

        signal.signal(signal.SIGTERM, _shutdown)
        signal.signal(signal.SIGINT, _shutdown)

        print(f"salt-daemon ready on {socket_path}", flush=True)
        log.info("Listening on %s", socket_path)

        while True:
            try:
                conn, _ = server.accept()
            except OSError:
                break
            t = threading.Thread(
                target=self.handle_client, args=(conn,), daemon=True
            )
            t.start()


# ── Entry point ───────────────────────────────────────────────────────────────
def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Pre-loaded Salt state daemon (saves ~0.4s per run)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--config-dir",
        default=_DEFAULT_CONFIG_DIR,
        metavar="DIR",
        help="Salt minion config directory",
    )
    parser.add_argument(
        "--socket",
        default=_DEFAULT_SOCKET,
        metavar="PATH",
        help="Unix socket path to listen on",
    )
    parser.add_argument(
        "--log-level",
        default="warning",
        choices=["debug", "info", "warning", "error"],
        help="Daemon log level",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=getattr(logging, args.log_level.upper()),
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
        stream=sys.stderr,
    )

    if os.geteuid() != 0:
        log.warning(
            "salt-daemon is not running as root — system state changes may fail"
        )

    try:
        opts, minion = load_salt(args.config_dir)
    except Exception as exc:
        log.critical("Failed to load Salt: %s", exc, exc_info=True)
        sys.exit(1)

    server = DaemonServer(args.socket, opts, minion)
    server.serve(args.socket)


if __name__ == "__main__":
    main()
