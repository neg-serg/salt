#!/bin/bash
# salt-apply.sh — apply Salt states (daemon-aware)
#
# Bootstraps venv + runtime config on first run, then uses the running
# salt-daemon if available, otherwise falls back to direct salt-call.
# Runs chezmoi apply after a successful state run.
#
# Usage:
#   scripts/salt-apply.sh                        # apply system_description
#   scripts/salt-apply.sh cachyos                # smoke-test bootstrap
#   scripts/salt-apply.sh hardware --test        # dry-run a specific state
#   scripts/salt-apply.sh kernel_modules
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
DAEMON_SCRIPT="${SCRIPT_DIR}/salt-daemon.py"

STATE="system_description"
TEST_MODE=false

for arg in "$@"; do
    case "$arg" in
        --test|--dry-run) TEST_MODE=true ;;
        -*) echo "Unknown flag: $arg" >&2; exit 1 ;;
        *) STATE="$arg" ;;
    esac
done

LOG_DIR="${PROJECT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${SALT_LOG_FILE:-${LOG_DIR}/${STATE}-${TIMESTAMP}.log}"
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

# ── Bootstrap: venv + Salt install ────────────────────────────────────────────
bootstrap_salt() {
    if [[ ! -d "$VENV_DIR" ]]; then
        echo "--- Bootstrapping Salt (creating venv) ---"
        python3 -m venv "$VENV_DIR"
    fi

    if [[ ! -f "$VENV_DIR/bin/salt-call" ]]; then
        echo "--- Installing Salt and dependencies ---"
        "$VENV_DIR/bin/pip" install salt passlib tornado jinja2 msgpack pyyaml psutil requests distro looseversion packaging pycryptodomex

        # Patch Salt for Python 3.14+ urlunparse behavior
        PYVER=$("$VENV_DIR/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
        URL_PY="$VENV_DIR/lib/python${PYVER}/site-packages/salt/utils/url.py"
        if [[ -f "$URL_PY" ]]; then
            echo "--- Patching Salt for Python 3.14 compatibility ---"
            sed -i 's/return "salt:\/\/{}".format(url\[len("file:\/\/\/") :\])/return "salt:\/\/{}".format(url.split("file:", 1)[1].lstrip("\/"))/' "$URL_PY"
        fi
    fi
}

# ── Runtime config: generate .salt_runtime/minion ─────────────────────────────
setup_config() {
    mkdir -p "${RUNTIME_CONFIG_DIR}/pki/minion" \
             "${RUNTIME_CONFIG_DIR}/var/cache/salt/pillar_cache" \
             "${RUNTIME_CONFIG_DIR}/var/log/salt"
    cat > "${RUNTIME_CONFIG_DIR}/minion" <<EOF
pki_dir: ${RUNTIME_CONFIG_DIR}/pki/minion
log_file: ${RUNTIME_CONFIG_DIR}/var/log/salt/minion
cachedir: ${RUNTIME_CONFIG_DIR}/var/cache/salt
minion_pillar_cache: True
pillar_cache: True
pillar_cache_backend: disk
pillar_cache_ttl: 3600
state_output: changes
file_client: local
file_roots:
  base:
    - ${PROJECT_DIR}/states/
    - ${PROJECT_DIR}/

# --- Performance optimizations ---
# Grains: skip expensive DNS reverse-lookup and hardware probes
enable_fqdns_grains: False
enable_gpu_grains: False
# Cache grain collection to disk; avoids full rebuild on every run
grains_cache: True
grains_cache_expiration: 3600
# Salt 3007+: skip expensive module fallback file scan
lazy_loader_strict_matching: True
# No custom _modules/ in this repo — skip saltutil.sync_all before each run
autoload_dynamic_modules: False
# Don't traverse non-SLS dirs (configs/, scripts/, units/, data/, build/)
fileserver_limit_traversal: True
# Limit parallel state processes (parallel: True in states)
process_count_max: 8
EOF
}

# ── Sudo: prefer NOPASSWD, fall back to .password file ────────────────────────
get_sudo() {
    if sudo -n true 2>/dev/null; then
        SUDO_CMD="sudo -E"
        SUDO_PASS=""
    elif [[ -f "${PROJECT_DIR}/.password" ]]; then
        SUDO_CMD="sudo -S -E"
        SUDO_PASS=$(cat "${PROJECT_DIR}/.password")
    else
        echo "error: no NOPASSWD sudo and no .password file found" >&2
        echo "  either configure NOPASSWD or create .password" >&2
        exit 1
    fi
}

# ── Daemon helpers ─────────────────────────────────────────────────────────────
daemon_running() {
    [[ -S "$DAEMON_SOCK" ]] || return 1
    if python3 -c "
import socket, sys
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1)
    s.connect('$DAEMON_SOCK')
    s.close()
except Exception:
    sys.exit(1)
" 2>/dev/null; then
        return 0
    fi
    # Socket exists but daemon is dead — remove stale socket so ensure_daemon
    # can start a fresh daemon without bind() failing on the existing path.
    $SUDO_CMD rm -f "$DAEMON_SOCK"
    return 1
}

ensure_daemon() {
    daemon_running && return 0
    [[ -x "$DAEMON_SCRIPT" ]] || return 1
    echo "(starting salt-daemon in background...)"
    $SUDO_CMD "$DAEMON_SCRIPT" \
        --config-dir "$RUNTIME_CONFIG_DIR" \
        --socket "$DAEMON_SOCK" \
        --log-level warning &>/dev/null &
    for _ in $(seq 1 10); do
        sleep 0.5
        daemon_running && return 0
    done
    return 1  # timeout — fall back to direct
}

# ── AWK formatter (shared by both run paths) ──────────────────────────────────
AWK_FORMATTER="${SCRIPT_DIR}/salt-formatter.awk"

# ── Run via daemon ─────────────────────────────────────────────────────────────
run_via_daemon() {
    echo "=== Applying ${STATE} via daemon ($(date)) ==="
    echo "Log: ${LOG_FILE}"

    tail -f "${LOG_FILE}" | awk -v maxlen=100 -f "$AWK_FORMATTER" &
    local tail_pid=$!

    local kwargs='{"state_output":"mixed_id"}'
    $TEST_MODE && kwargs='{"state_output":"mixed_id","test":true}'

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

# ── Fallback: direct salt-call ─────────────────────────────────────────────────
SALT_RUNNER="${SCRIPT_DIR}/salt-runner.py"

run_direct() {
    echo "=== Applying ${STATE} directly (daemon not running) ($(date)) ==="
    echo "Log: ${LOG_FILE}"
    echo "(Start salt-daemon for faster subsequent runs)"

    tail -f "${LOG_FILE}" | awk -v maxlen=100 -f "$AWK_FORMATTER" &
    local tail_pid=$!

    local test_arg=""
    $TEST_MODE && test_arg="test=True"

    if [[ -n "${SUDO_PASS:-}" ]]; then
        echo "$SUDO_PASS" | $SUDO_CMD "$VENV_DIR/bin/python3" -u "$SALT_RUNNER" \
            --config-dir="${RUNTIME_CONFIG_DIR}" \
            --local --log-level=warning \
            --log-file="${LOG_FILE}" --log-file-level=debug \
            --state-output=mixed_id \
            state.sls "${STATE}" ${test_arg} 2>&1 | tee -a "${LOG_FILE}" > /dev/null
    else
        $SUDO_CMD "$VENV_DIR/bin/python3" -u "$SALT_RUNNER" \
            --config-dir="${RUNTIME_CONFIG_DIR}" \
            --local --log-level=warning \
            --log-file="${LOG_FILE}" --log-file-level=debug \
            --state-output=mixed_id \
            state.sls "${STATE}" ${test_arg} 2>&1 | tee -a "${LOG_FILE}" > /dev/null
    fi
    local rc="${PIPESTATUS[0]}"

    sleep 0.3
    kill "$tail_pid" 2>/dev/null
    wait "$tail_pid" 2>/dev/null
    return "$rc"
}

# ── Main ───────────────────────────────────────────────────────────────────────
bootstrap_salt
setup_config
get_sudo

if ensure_daemon; then
    run_via_daemon
    RC=$?
else
    run_direct
    RC=$?
fi

# ── Post-run: check log for errors that may have been missed ──────────────────
check_log_errors() {
    local critical_count
    critical_count=$(rg -c '\[CRITICAL\]' "$LOG_FILE" 2>/dev/null || echo 0)
    if [[ "$critical_count" -gt 0 ]]; then
        echo ""
        printf '\033[31m━━━ %d critical error(s) found ━━━\033[0m\n' "$critical_count"
        rg '\[CRITICAL\]' "$LOG_FILE" | while IFS= read -r line; do
            msg="${line##*\] }"
            printf '\033[31m  ✗ %s\033[0m\n' "$msg"
        done
        # Force non-zero exit if salt reported success despite critical errors
        if [[ $RC -eq 0 ]]; then
            RC=1
        fi
    fi
}

echo ""
check_log_errors
echo "=== Finished ${STATE} (exit code: ${RC}) at $(date) ==="
echo "Full log: ${LOG_FILE}"

if [[ $RC -eq 0 ]]; then
    echo "--- ${STATE}: all states passed ---"
    echo "--- Applying dotfiles (chezmoi) ---"
    chezmoi apply --force --source "${PROJECT_DIR}/dotfiles"
else
    echo "--- ${STATE}: some states failed (see log above) ---"
    exit $RC
fi
