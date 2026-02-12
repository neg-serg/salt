#!/bin/bash
set -uo pipefail

# --- Bootstrap Environment ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
CONFIG_DIR="${SCRIPT_DIR}/salt_config"
SUDO_PASS=$(cat "${SCRIPT_DIR}/.password")
ACTION="state.sls"
STATE="system_description"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/${STATE}-${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

bootstrap_salt() {
  if [[ ! -d "$VENV_DIR" ]]; then
    echo "--- Bootstrapping Salt (creating venv) ---"
    python3 -m venv "$VENV_DIR"
  fi

  if [[ ! -f "$VENV_DIR/bin/salt-call" ]]; then
    echo "--- Installing Salt and dependencies ---"
    # Python 3.14+ might have issues with salt's metadata or dependencies
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

run_salt() {
  local extra_args="${1:-}"
  echo "=== Applying ${STATE} ($(date)) ==="
  echo "Log: ${LOG_FILE}"
  echo "$SUDO_PASS" | sudo -S -E "$VENV_DIR/bin/python3" "${SCRIPT_DIR}/run_salt.py" \
    --config-dir="${CONFIG_DIR}" \
    --local \
    --log-level=warning \
    --log-file="${LOG_FILE}" \
    --log-file-level=debug \
    --state-output=mixed_id \
    ${ACTION} ${STATE} ${extra_args} 2>&1 | tee -a "${LOG_FILE}"
  return "${PIPESTATUS[0]}"
}

# Ensure Salt is ready
bootstrap_salt

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
    echo "--- Applying dotfiles (chezmoi) ---"
    chezmoi apply --force --source "${SCRIPT_DIR}/dotfiles"
  else
    echo "--- Skipping chezmoi (salt failed) ---"
    exit $RC
  fi
fi
