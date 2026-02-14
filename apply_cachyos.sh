#!/bin/bash
set -uo pipefail

# Apply CachyOS verification/configuration state via Salt.
# Analogous to apply_config.sh but targets the cachyos.sls state.
#
# Usage:
#   ./apply_cachyos.sh            # apply state
#   ./apply_cachyos.sh --dry-run  # test mode (no changes)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
ACTION="state.sls"
STATE="cachyos"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/${STATE}-${TIMESTAMP}.log"

# Runtime salt config (paths derived from SCRIPT_DIR, works on both
# Fedora Atomic /var/home and standard Arch /home)
RUNTIME_CONFIG_DIR="${SCRIPT_DIR}/.salt_runtime"

mkdir -p "${LOG_DIR}"

setup_config() {
  mkdir -p "${RUNTIME_CONFIG_DIR}/pki/minion" "${RUNTIME_CONFIG_DIR}/var/cache/salt" "${RUNTIME_CONFIG_DIR}/var/log/salt"
  cat > "${RUNTIME_CONFIG_DIR}/minion" <<EOF
pki_dir: ${RUNTIME_CONFIG_DIR}/pki/minion
log_file: ${RUNTIME_CONFIG_DIR}/var/log/salt/minion
cachedir: ${RUNTIME_CONFIG_DIR}/var/cache/salt
minion_pillar_cache: True
pillar_cache: True
pillar_cache_backend: disk
pillar_cache_ttl: 3600
file_roots:
  base:
    - ${SCRIPT_DIR}/states/
    - ${SCRIPT_DIR}/
EOF
}

bootstrap_salt() {
  if [[ ! -d "$VENV_DIR" ]]; then
    echo "--- Bootstrapping Salt (creating venv) ---"
    python3 -m venv "$VENV_DIR"
  fi

  if [[ ! -f "$VENV_DIR/bin/salt-call" ]]; then
    echo "--- Installing Salt and dependencies ---"
    "$VENV_DIR/bin/pip" install salt passlib tornado jinja2 msgpack pyyaml psutil requests distro looseversion packaging pycryptodomex

    # Patch Salt for Python 3.14+ urlunparse behavior (character swallowing)
    PYVER=$("$VENV_DIR/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    URL_PY="$VENV_DIR/lib/python${PYVER}/site-packages/salt/utils/url.py"
    if [[ -f "$URL_PY" ]]; then
      echo "--- Patching Salt for Python 3.14 compatibility ---"
      sed -i 's/return "salt:\/\/{}".format(url\[len("file:\/\/\/") :\])/return "salt:\/\/{}".format(url.split("file:", 1)[1].lstrip("\/"))/' "$URL_PY"
    fi
  fi
}

get_sudo() {
  # Use NOPASSWD if available, otherwise read from .password file
  if sudo -n true 2>/dev/null; then
    SUDO_CMD="sudo -E"
  elif [[ -f "${SCRIPT_DIR}/.password" ]]; then
    SUDO_CMD="sudo -S -E"
    SUDO_PASS=$(cat "${SCRIPT_DIR}/.password")
  else
    echo "error: no NOPASSWD sudo and no .password file found" >&2
    echo "  either configure NOPASSWD or create .password" >&2
    exit 1
  fi
}

run_salt() {
  local extra_args="${1:-}"
  echo "=== Applying ${STATE} ($(date)) ==="
  echo "Log: ${LOG_FILE}"

  # Show state progress from the debug log in real-time
  touch "${LOG_FILE}"
  tail -f "${LOG_FILE}" | awk -v maxlen=100 '
    match($0, /Executing state ([^ ]+) for \[([^]]+)\]/, m) {
      line = "▶ " m[1] " " m[2]
      if (length(line) > maxlen) line = substr(line, 1, maxlen) "…"
      printf "\r\033[K%s", line
      fflush()
    }
    match($0, /Completed state \[([^]]+)\].*duration_in_ms=([^)]+)\)/, m) {
      suffix = " (" m[2] "ms)"
      name = "✓ " m[1]
      cut = maxlen - length(suffix)
      if (length(name) > cut) name = substr(name, 1, cut) "…"
      printf "\r\033[K%s\n", name suffix
      fflush()
    }' &
  local tail_pid=$!

  if [[ -n "${SUDO_PASS:-}" ]]; then
    echo "$SUDO_PASS" | $SUDO_CMD "$VENV_DIR/bin/python3" "${SCRIPT_DIR}/run_salt.py" \
      --config-dir="${RUNTIME_CONFIG_DIR}" \
      --local \
      --log-level=warning \
      --log-file="${LOG_FILE}" \
      --log-file-level=debug \
      --state-output=mixed_id \
      ${ACTION} ${STATE} ${extra_args} 2>&1 | tee -a "${LOG_FILE}"
  else
    $SUDO_CMD "$VENV_DIR/bin/python3" "${SCRIPT_DIR}/run_salt.py" \
      --config-dir="${RUNTIME_CONFIG_DIR}" \
      --local \
      --log-level=warning \
      --log-file="${LOG_FILE}" \
      --log-file-level=debug \
      --state-output=mixed_id \
      ${ACTION} ${STATE} ${extra_args} 2>&1 | tee -a "${LOG_FILE}"
  fi
  local rc="${PIPESTATUS[0]}"

  kill "$tail_pid" 2>/dev/null
  wait "$tail_pid" 2>/dev/null
  return "$rc"
}

# Ensure Salt is ready
bootstrap_salt
setup_config
get_sudo

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "--- Running in test mode (no changes will be applied) ---"
  run_salt "test=True"
else
  run_salt ""
  RC=$?
  echo ""
  echo "=== Finished salt (exit code: ${RC}) at $(date) ==="
  echo "Full log: ${LOG_FILE}"
  if [[ $RC -eq 0 ]]; then
    echo "--- All CachyOS checks passed ---"
    echo "--- Applying dotfiles (chezmoi) ---"
    chezmoi apply --force --source "${SCRIPT_DIR}/dotfiles"
  else
    echo "--- Some checks failed (see log above) ---"
    exit $RC
  fi
fi
