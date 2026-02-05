#!/bin/bash
set -e

# --- Bootstrap Environment ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"
CONFIG_DIR="/var/home/neg/.gemini/tmp/salt_config"
SUDO_PASS=$(cat "${SCRIPT_DIR}/.password")
ACTION="state.sls"
STATE="system_description"

bootstrap_salt() {
  if [[ ! -d "$VENV_DIR" ]]; then
    echo "--- Bootstrapping Salt (creating venv) ---"
    python3 -m venv "$VENV_DIR"
  fi

  if [[ ! -f "$VENV_DIR/bin/salt-call" ]]; then
    echo "--- Installing Salt and dependencies ---"
    # Python 3.14+ might have issues with salt's metadata or dependencies
    "$VENV_DIR/bin/pip" install salt passlib tornado jinja2 msgpack pyyaml psutil requests distro looseversion packaging pycryptodomex

    # Patch Salt for Python 3.14 urlunparse behavior (character swallowing)
    URL_PY="$VENV_DIR/lib/python3.14/site-packages/salt/utils/url.py"
    if [[ -f "$URL_PY" ]]; then
      echo "--- Patching Salt for Python 3.14 compatibility ---"
      sed -i 's/return "salt:\/\/{}".format(url\[len("file:\/\/\/") :\])/return "salt:\/\/{}".format(url.split("file:", 1)[1].lstrip("\/"))/' "$URL_PY"
    fi
  fi
}

run_salt() {
  local extra_args="$1"
  # Use the venv python to run the wrapper
  echo "$SUDO_PASS" | sudo -S -E "$VENV_DIR/bin/python3" "${SCRIPT_DIR}/run_salt.py" \
    --config-dir="${CONFIG_DIR}" \
    -l info \
    --local ${ACTION} ${STATE} ${extra_args}
}

# Ensure Salt is ready
bootstrap_salt

if [[ "$1" == "--dry-run" ]]; then
  echo "--- Running in test mode (no changes will be applied) ---"
  run_salt "test=True"
else
  echo "--- Applying configuration ---"
  run_salt ""
  echo "--- Applying dotfiles (chezmoi) ---"
  chezmoi apply --force --source "${SCRIPT_DIR}/dotfiles"
fi
