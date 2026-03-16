#!/usr/bin/env python3
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
    that salt-apply.sh's awk watcher expects to read via `tail -f`.
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
import struct
import sys

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

# ── Python 3.13+ compatibility shims (PEP 594 removals) ─────────────────────
import salt_compat

salt_compat.patch()

# ── Defaults ─────────────────────────────────────────────────────────────────
_DEFAULT_SOCKET = "/run/salt-daemon.sock"
_DEFAULT_CONFIG_DIR = os.path.join(_SCRIPT_DIR, ".salt_runtime")
_DEFAULT_TIMEOUT = 1800  # 30 minutes per state run (large model downloads)


class StateTimeout(Exception):
    """Raised by SIGALRM when a state execution exceeds the timeout."""


def _on_sigalrm(signum, frame):
    raise StateTimeout("state execution timed out")


# ── Security: allowed log directory and state whitelist ──────────────────────
_ALLOWED_LOG_DIR = os.path.join(_SCRIPT_DIR, "logs")


def _discover_allowed_states():
    """Build allowed state set from states/*.sls files on disk."""
    import glob

    states_dir = os.path.join(_SCRIPT_DIR, "states")
    found = set()
    for path in glob.glob(os.path.join(states_dir, "*.sls")):
        name = os.path.basename(path).removesuffix(".sls")
        found.add(name)
    return frozenset(found)


_ALLOWED_STATES = _discover_allowed_states()

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

    # Initialize Salt's logging options dict so forked child processes
    # (parallel: True states) inherit a valid __logging_config__.
    # Without this, Process.__new__ stores None, and the child crashes in
    # set_logging_options_dict(None) → NoneType.get("log_level").
    import salt._logging

    salt._logging.set_logging_options_dict(opts)

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
      debug lines go to log_file (for salt-apply.sh's awk/tail watcher).
    - Captures stdout so salt.output.display_output writes are caught.
    - Appends formatted stdout to log_file (for the awk summary watcher).
    - Sends all output lines to client as {"type": "stdout", "line": "..."}.
    """
    import salt.output

    def send(obj: dict) -> None:
        try:
            client_sock.sendall((json.dumps(obj) + "\n").encode())
        except OSError:
            log.debug("Client disconnected during send")

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
        filtered = {k: v for k, v in kwargs.items() if k != "state_output"}
        result = minion.functions["state.sls"](state, **filtered)

        # ── Format and emit output ───────────────────────────────────────
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

    except Exception as exc:
        err_msg = f"salt-daemon: error running state.sls({state!r}): {exc}"
        log.exception(err_msg)
        send({"type": "stdout", "line": err_msg})
        send({"type": "exit", "code": 1})
        exit_code = 1

    finally:
        # ── Teardown file handler (always runs, even on timeout/error) ───
        if file_handler is not None:
            logging.root.removeHandler(file_handler)
            file_handler.close()
        logging.root.setLevel(saved_root_level)

    return exit_code


# ── Socket server ─────────────────────────────────────────────────────────────
class DaemonServer:
    def __init__(self, socket_path: str, opts: dict, minion, timeout: int = _DEFAULT_TIMEOUT):
        self.socket_path = socket_path
        self.opts = opts
        self.minion = minion
        self.timeout = timeout
        # Build allowed UID set: root + all members of the wheel group
        import grp
        import pwd

        self.allowed_uids = {0}  # root always allowed
        try:
            wheel = grp.getgrnam("wheel")
            for username in wheel.gr_mem:
                try:
                    self.allowed_uids.add(pwd.getpwnam(username).pw_uid)
                except KeyError:
                    pass
        except KeyError:
            pass
        log.info("Allowed UIDs for socket connections: %s", self.allowed_uids)

    def handle_client(self, conn: socket.socket) -> None:
        # ── Verify peer credentials (SO_PEERCRED) ────────────────────────
        # Only allow root (uid 0) and the primary user (uid from _ALLOWED_UID).
        try:
            cred = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("iII"))
            peer_pid, peer_uid, peer_gid = struct.unpack("iII", cred)
        except (OSError, struct.error) as exc:
            log.warning("Cannot get peer credentials: %s", exc)
            conn.close()
            return

        if peer_uid not in self.allowed_uids:
            log.warning(
                "Rejected connection from uid=%d pid=%d (allowed: %s)",
                peer_uid,
                peer_pid,
                self.allowed_uids,
            )
            conn.close()
            return

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
        req_timeout = request.get("timeout")
        if isinstance(req_timeout, int) and 0 < req_timeout <= 14400:
            effective_timeout = req_timeout
        else:
            effective_timeout = self.timeout

        # ── Validate state name ──────────────────────────────────────────
        if state not in _ALLOWED_STATES:
            log.warning("Rejected disallowed state: %r", state)
            try:
                msg = f"error: state {state!r} not in allowed list"
                conn.sendall((json.dumps({"type": "stdout", "line": msg}) + "\n").encode())
                conn.sendall((json.dumps({"type": "exit", "code": 1}) + "\n").encode())
            except OSError:
                pass
            conn.close()
            return

        # ── Validate log_file path (restrict to project logs/ dir) ───────
        if log_file:
            real_log = os.path.realpath(log_file)
            allowed_dir = os.path.realpath(_ALLOWED_LOG_DIR)
            if not real_log.startswith(allowed_dir + os.sep):
                log.warning(
                    "Rejected log_file outside allowed dir: %r (resolved to %r)",
                    log_file,
                    real_log,
                )
                log_file = ""

        log.info(
            "Request: state=%r kwargs=%s log_file=%r timeout=%ds",
            state,
            kwargs,
            log_file,
            effective_timeout,
        )

        signal.alarm(effective_timeout)
        try:
            run_state(self.opts, self.minion, state, kwargs, log_file, conn)
        except StateTimeout:
            log.error("State %r timed out after %ds", state, effective_timeout)
            try:
                msg = f"error: state {state!r} timed out after {effective_timeout}s"
                conn.sendall((json.dumps({"type": "stdout", "line": msg}) + "\n").encode())
                conn.sendall((json.dumps({"type": "exit", "code": 1}) + "\n").encode())
            except OSError:
                pass
        except Exception as exc:
            log.exception("Unhandled error in run_state: %s", exc)
            try:
                conn.sendall((json.dumps({"type": "exit", "code": 1}) + "\n").encode())
            except OSError:
                pass
        finally:
            signal.alarm(0)

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
        signal.signal(signal.SIGALRM, _on_sigalrm)

        print(f"salt-daemon ready on {socket_path}", flush=True)
        log.info("Listening on %s", socket_path)

        while True:
            try:
                conn, _ = server.accept()
            except OSError:
                break
            # Handle synchronously — no threads, so parallel: True in Salt
            # states can safely fork() without inheriting locked mutexes.
            self.handle_client(conn)


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
        "--timeout",
        type=int,
        default=_DEFAULT_TIMEOUT,
        metavar="SEC",
        help="Max seconds per state run (0 = no limit)",
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
        log.warning("salt-daemon is not running as root — system state changes may fail")

    try:
        opts, minion = load_salt(args.config_dir)
    except Exception as exc:
        log.critical("Failed to load Salt: %s", exc, exc_info=True)
        sys.exit(1)

    server = DaemonServer(args.socket, opts, minion, timeout=args.timeout)
    server.serve(args.socket)


if __name__ == "__main__":
    main()
