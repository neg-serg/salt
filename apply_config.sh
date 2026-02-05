#!/bin/bash
CONFIG_DIR="/var/home/neg/.gemini/tmp/salt_config"
SUDO_PASS=$(cat "/var/home/neg/src/salt/.password")
ACTION="state.sls"
STATE="system_description"

run_salt() {
  local extra_args="$1"
  echo "$SUDO_PASS" | sudo -S -E python3.14 /var/home/neg/src/salt/run_salt.py \
    --config-dir="${CONFIG_DIR}" \
    -l info \
    --local ${ACTION} ${STATE} ${extra_args}
}

if [[ "$1" == "--dry-run" ]]; then
  echo "--- Running in test mode (no changes will be applied) ---"
  run_salt "test=True"
else
  echo "--- Applying configuration ---"
  run_salt ""
fi
