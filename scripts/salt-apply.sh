#!/bin/bash
# salt-apply.sh — client for salt-daemon.py
#
# Sends a state.apply request to the running salt-daemon and streams
# the output. Falls back to direct salt-call if the daemon is not running.
#
# Usage:
#   scripts/salt-apply.sh [state] [--test] [--dry-run]
#   scripts/salt-apply.sh system_description
#   scripts/salt-apply.sh hardware --test
#
# Environment:
#   SALT_DAEMON_SOCK  Unix socket path (default: /tmp/salt-daemon.sock)
#   SALT_LOG_FILE     Override log file path

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="${PROJECT_DIR}/.venv"
RUNTIME_CONFIG_DIR="${PROJECT_DIR}/.salt_runtime"
DAEMON_SOCK="${SALT_DAEMON_SOCK:-/tmp/salt-daemon.sock}"

STATE="system_description"
TEST_MODE=false
EXTRA_ARGS=()

for arg in "$@"; do
    case "$arg" in
        --test|--dry-run) TEST_MODE=true ;;
        -*) EXTRA_ARGS+=("$arg") ;;
        *) STATE="$arg" ;;
    esac
done

LOG_DIR="${PROJECT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${SALT_LOG_FILE:-${LOG_DIR}/${STATE}-${TIMESTAMP}.log}"
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

# ── Check if daemon is running ────────────────────────────────────────────────
daemon_running() {
    [[ -S "$DAEMON_SOCK" ]] || return 1
    # Try a quick connection test (bare 'except:' would catch sys.exit(0), use Exception)
    python3 -c "
import socket, sys
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1)
    s.connect('$DAEMON_SOCK')
    s.close()
except Exception:
    sys.exit(1)
" 2>/dev/null
}

# ── Run via daemon ────────────────────────────────────────────────────────────
run_via_daemon() {
    echo "=== Applying ${STATE} via daemon ($(date)) ==="
    echo "Log: ${LOG_FILE}"

    # The daemon writes both debug logs and the formatted summary directly to
    # LOG_FILE.  The awk watcher reads from LOG_FILE via tail -f — same as the
    # direct (non-daemon) path.  The client only needs to send the request and
    # capture the exit code; no tee-ing needed (would duplicate summary lines).
    tail -f "${LOG_FILE}" | awk -v maxlen=100 '
        match($0, /Executing state ([^ ]+) for \[([^]]+)\]/, m) {
            state_n++
            line = "▶ [" state_n "] " m[1] " " m[2]
            if (length(line) > maxlen) line = substr(line, 1, maxlen) "…"
            printf "\r\033[K%s", line
            fflush()
        }
        /^local:/ {
            printf "\r\033[K"
            fflush()
        }
        match($0, /^  Name: ([^ ]+) - Function: ([^ ]+) - Result: ([^ ]+) - Started: [^ ]+ - Duration: ([0-9.]+ ms)/, m) {
            dur = " (" m[4] ")"
            if (m[3] == "Changed") mark = "\033[33m✦\033[0m"
            else if (m[3] ~ /^Fail/) mark = "\033[31m✗\033[0m"
            else mark = "✓"
            name = mark " " m[1]
            cut = maxlen - length(dur) + 9
            printf "%s%s\n", name, dur
            fflush()
        }
        /^Summary for / { in_summary=1 }
        in_summary && /^[-]+$/ { print; fflush() }
        in_summary && /^(Succeeded|Failed|Total)/ { print; fflush() }
    ' &
    local tail_pid=$!

    # Build kwargs JSON
    local kwargs='{"state_output":"mixed_id"}'
    $TEST_MODE && kwargs='{"state_output":"mixed_id","test":true}'

    # Talk to daemon: send JSON request, wait for {"type":"exit","code":N}.
    # The daemon writes all output to LOG_FILE directly; we only capture the
    # exit code here so the shell can propagate it.
    # Note: kwargs is a JSON string; parse it so Python gets proper booleans.
    local exit_code
    exit_code=$(python3 - <<PYEOF
import json, socket, sys
req = json.dumps({
    'state': '${STATE}',
    'kwargs': json.loads('${kwargs}'),
    'log_file': '${LOG_FILE}'
}) + '\n'
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('${DAEMON_SOCK}')
s.sendall(req.encode())
buf = b''
rc = 1
while True:
    chunk = s.recv(4096)
    if not chunk:
        break
    buf += chunk
    while b'\n' in buf:
        line, buf = buf.split(b'\n', 1)
        if not line:
            continue
        try:
            msg = json.loads(line.decode())
        except json.JSONDecodeError:
            continue
        if msg.get('type') == 'exit':
            rc = msg.get('code', 0)
s.close()
print(rc)
PYEOF
    )

    sleep 0.3
    kill "$tail_pid" 2>/dev/null
    wait "$tail_pid" 2>/dev/null

    return "${exit_code:-1}"
}

# ── Fallback: direct salt-call ────────────────────────────────────────────────
run_direct() {
    echo "=== Applying ${STATE} directly (daemon not running) ($(date)) ==="
    echo "Log: ${LOG_FILE}"
    echo "(Start salt-daemon for faster subsequent runs)"

    SALT_RUNNER='
import sys, warnings
_orig = warnings.showwarning
def _w(msg, cat, filename, lineno, file=None, line=None):
    if cat is DeprecationWarning and "/salt/" in (filename or ""): return
    _orig(msg, cat, filename, lineno, file, line)
warnings.showwarning = _w

class MockCrypt:
    def __init__(self):
        try:
            import passlib.hash as hash; self.hash = hash
        except ImportError:
            self.hash = None
        class Method:
            def __init__(self, n, i): self.name = n; self.ident = i
        self.methods = [Method("sha512","6"),Method("sha256","5"),Method("md5","1"),Method("crypt","")]
    def crypt(self, word, salt):
        if not self.hash: raise ImportError("passlib required")
        from passlib.hash import des_crypt, md5_crypt, sha256_crypt, sha512_crypt
        if salt.startswith("$6$"): return sha512_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$5$"): return sha256_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$1$"): return md5_crypt.hash(word, salt=salt.split("$")[2])
        return des_crypt.hash(word, salt=salt)
sys.modules["crypt"] = MockCrypt()
class MockSpwd:
    def getspnam(self, name): raise KeyError(f"spwd: {name}")
sys.modules["spwd"] = MockSpwd()
import salt.scripts; salt.scripts.salt_call()
'

    touch "${LOG_FILE}"
    tail -f "${LOG_FILE}" | awk -v maxlen=100 '
        match($0, /Executing state ([^ ]+) for \[([^]]+)\]/, m) {
            state_n++
            line = "▶ [" state_n "] " m[1] " " m[2]
            if (length(line) > maxlen) line = substr(line, 1, maxlen) "…"
            printf "\r\033[K%s", line; fflush()
        }
        /^local:/ { printf "\r\033[K"; fflush() }
        match($0, /^  Name: ([^ ]+) - Function: ([^ ]+) - Result: ([^ ]+) - Started: [^ ]+ - Duration: ([0-9.]+ ms)/, m) {
            dur = " (" m[4] ")"
            if (m[3] == "Changed") mark = "\033[33m✦\033[0m"
            else if (m[3] ~ /^Fail/) mark = "\033[31m✗\033[0m"
            else mark = "✓"
            printf "%s%s\n", mark " " m[1], dur; fflush()
        }
        /^Summary for / { in_summary=1 }
        in_summary && /^[-]+$/ { print; fflush() }
        in_summary && /^(Succeeded|Failed|Total)/ { print; fflush() }
    ' &
    local tail_pid=$!

    local test_arg=""
    $TEST_MODE && test_arg="test=True"

    sudo -E "${VENV_DIR}/bin/python3" -u -c "$SALT_RUNNER" \
        --config-dir="${RUNTIME_CONFIG_DIR}" \
        --local \
        --log-level=warning \
        --log-file="${LOG_FILE}" \
        --log-file-level=debug \
        --state-output=mixed_id \
        state.sls "${STATE}" ${test_arg} 2>&1 | tee -a "${LOG_FILE}" > /dev/null
    local rc="${PIPESTATUS[0]}"

    sleep 0.3
    kill "$tail_pid" 2>/dev/null
    wait "$tail_pid" 2>/dev/null
    return "$rc"
}

# ── Main ──────────────────────────────────────────────────────────────────────
if daemon_running; then
    run_via_daemon
    RC=$?
else
    run_direct
    RC=$?
fi

echo ""
echo "=== Finished ${STATE} (exit code: ${RC}) at $(date) ==="
echo "Full log: ${LOG_FILE}"

if [[ $RC -eq 0 ]]; then
    echo "--- ${STATE}: all states passed ---"
else
    echo "--- ${STATE}: some states failed (see log above) ---"
    exit $RC
fi
