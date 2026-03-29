#!/usr/bin/env zsh
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

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="${PROJECT_DIR}/.venv"
RUNTIME_CONFIG_DIR="${PROJECT_DIR}/.salt_runtime"
DAEMON_SOCK="${SALT_DAEMON_SOCK:-/run/salt-daemon.sock}"
DAEMON_SCRIPT="${SCRIPT_DIR}/salt-daemon.py"
source "${SCRIPT_DIR}/salt-runtime.sh"

STATE="system_description"
TEST_MODE=false
SNAPPER_PRE_NUM=""

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
install -m 0640 /dev/null "${LOG_FILE}"

# ── Bootstrap: venv + Salt install ────────────────────────────────────────────
bootstrap_salt() {
    if [[ ! -d "$VENV_DIR" ]]; then
        echo "--- Bootstrapping Salt (creating venv) ---"
        python3 -m venv "$VENV_DIR"
    fi

    if [[ ! -f "$VENV_DIR/bin/salt-call" ]]; then
        echo "--- Installing Salt and dependencies ---"
        "$VENV_DIR/bin/pip" install -r "${PROJECT_DIR}/requirements.txt"
    fi
}

# ── Runtime config: generate .salt_runtime/minion ─────────────────────────────
setup_config() {
    [[ -f "${RUNTIME_CONFIG_DIR}/minion" ]] && return 0
    salt_runtime_prepare_dirs "${PROJECT_DIR}" "${RUNTIME_CONFIG_DIR}"
    salt_runtime_write_minion_config "${PROJECT_DIR}" "${RUNTIME_CONFIG_DIR}" apply
}

# ── Sudo: prefer NOPASSWD, fall back to .password file ────────────────────────
get_sudo() {
    if sudo -n true 2>/dev/null; then
        SUDO_CMD=(sudo)
        SUDO_PASS=""
    elif [[ -f "${PROJECT_DIR}/.password" ]]; then
        SUDO_CMD=(sudo -S)
        SUDO_PASS=$(<"${PROJECT_DIR}/.password")
    else
        echo "error: no NOPASSWD sudo and no .password file found" >&2
        echo "  either configure NOPASSWD or create .password" >&2
        exit 1
    fi
}

# ── Snapper: pre/post-apply snapshots ──────────────────────────────────────────
# Pre-snapshot runs in the background while Salt starts up, saving ~2s.
SNAPPER_PRE_PID=""
SNAPPER_PRE_TMPFILE=""

snapshot_pre() {
    if command -v snapper &>/dev/null; then
        SNAPPER_PRE_TMPFILE=$(mktemp)
        (
            num=$("${SUDO_CMD[@]}" snapper create --type pre --print-number \
                  --cleanup-algorithm number \
                  --description "salt-pre: ${STATE}" 2>/dev/null) || exit 0
            echo "$num" > "$SNAPPER_PRE_TMPFILE"
        ) &
        SNAPPER_PRE_PID=$!
    fi
}

snapshot_pre_collect() {
    if [[ -n "${SNAPPER_PRE_PID:-}" ]]; then
        wait "$SNAPPER_PRE_PID" 2>/dev/null || true
        if [[ -s "${SNAPPER_PRE_TMPFILE:-}" ]]; then
            SNAPPER_PRE_NUM=$(<"$SNAPPER_PRE_TMPFILE")
            echo "(snapshot #${SNAPPER_PRE_NUM}: pre-apply)"
        fi
        rm -f "${SNAPPER_PRE_TMPFILE:-}" 2>/dev/null
    fi
}

snapshot_post() {
    if [[ -n "${SNAPPER_PRE_NUM:-}" ]]; then
        local num
        num=$("${SUDO_CMD[@]}" snapper create --type post --pre-number "${SNAPPER_PRE_NUM}" \
              --print-number --cleanup-algorithm number \
              --description "salt-post: ${STATE}" 2>/dev/null) || return 0
        echo "(snapshot #${num}: post-apply, pre=#${SNAPPER_PRE_NUM})"
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
    "${SUDO_CMD[@]}" rm -f "$DAEMON_SOCK"
    return 1
}

ensure_daemon() {
    daemon_running && return 0
    [[ -x "$DAEMON_SCRIPT" ]] || return 1
    echo "(starting salt-daemon in background...)"
    "${SUDO_CMD[@]}" "$DAEMON_SCRIPT" \
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
    kill "$tail_pid" 2>/dev/null || true
    wait "$tail_pid" 2>/dev/null || true
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

    local -a salt_cmd
    salt_cmd=(
        "${SUDO_CMD[@]}" "$VENV_DIR/bin/python3" -u "$SALT_RUNNER"
        --config-dir="${RUNTIME_CONFIG_DIR}"
        --local --log-level=warning
        --log-file="${LOG_FILE}" --log-file-level=debug
        --state-output=mixed_id
        state.sls "${STATE}"
    )
    $TEST_MODE && salt_cmd+=(test=True)

    if [[ -n "${SUDO_PASS:-}" ]]; then
        echo "$SUDO_PASS" | "${salt_cmd[@]}" 2>&1 | tee -a "${LOG_FILE}" > /dev/null
        local rc="${pipestatus[2]}"
    else
        "${salt_cmd[@]}" 2>&1 | tee -a "${LOG_FILE}" > /dev/null
        local rc="${pipestatus[1]}"
    fi

    sleep 0.3
    kill "$tail_pid" 2>/dev/null || true
    wait "$tail_pid" 2>/dev/null || true
    return "$rc"
}

# ── Maintenance lock (suppresses salt-monitor alerts during apply) ─────────────
MAINTENANCE_LOCK="${HOME}/.cache/salt-monitor/maintenance.lock"

maintenance_lock_create() {
    mkdir -p "${HOME}/.cache/salt-monitor"
    touch "$MAINTENANCE_LOCK"
}

maintenance_lock_remove() {
    rm -f "$MAINTENANCE_LOCK"
}

# ── Main ───────────────────────────────────────────────────────────────────────
bootstrap_salt
setup_config
get_sudo

maintenance_lock_create
trap maintenance_lock_remove EXIT

snapshot_pre

if ensure_daemon; then
    run_via_daemon
    RC=$?
    if [[ $RC -eq 75 ]]; then
        echo "(daemon busy — falling back to direct salt-call)"
        run_direct
        RC=$?
    fi
else
    run_direct
    RC=$?
fi

snapshot_pre_collect

# Post-snapshot runs detached — we don't need to wait for it
snapshot_post &
disown

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
    # Keep the existing GPG flow usable by refreshing pinentry TTY when that backend is in use.
    gpg-connect-agent updatestartuptty /bye &>/dev/null || true
    # Bootstrap chezmoi config before apply (needed for gopass template rendering)
    install -Dm644 "${PROJECT_DIR}/dotfiles/dot_config/chezmoi/chezmoi.toml" \
        "${HOME}/.config/chezmoi/chezmoi.toml" 2>/dev/null || true
    chezmoi_output=""
    if ! chezmoi_output=$(chezmoi apply --force --source "${PROJECT_DIR}/dotfiles" 2>&1); then
        echo ""
        printf '\033[33m━━━ chezmoi apply failed ━━━\033[0m\n'
        printf '\033[33m  Salt states succeeded; dotfiles were not fully applied.\033[0m\n'

        if printf '%s\n' "$chezmoi_output" | rg -qi 'gopass|pinentry|failed to decrypt|decryption failed'; then
            printf '\033[33m  Reason: gopass is locked or pinentry is unavailable in this session.\033[0m\n'
            printf '\033[33m  Action: unlock gopass, then re-run: chezmoi apply --force --source %s/dotfiles\033[0m\n' "${PROJECT_DIR}"
            printf '\033[33m  Verify: gopass show -o <known-key> (gopass ls alone does not prove decryption works).\033[0m\n'
            printf '\033[33m  Details: see docs/gopass-setup.md if the unlock path is not configured.\033[0m\n'
            printf '\033[33m  Continuing: Salt rollout succeeded; dotfiles were skipped for now.\033[0m\n'
        else
            printf '%s\n' "$chezmoi_output"
            printf '\033[33m  Re-run: chezmoi apply --force --source %s/dotfiles\033[0m\n' "${PROJECT_DIR}"
            exit 1
        fi
    fi
else
    echo "--- ${STATE}: some states failed (see log above) ---"
    exit $RC
fi
