#!/bin/bash
CONFIG_DIR="/var/home/neg/.gemini/tmp/salt_config"
SUDO_PASS=$(cat "/var/home/neg/src/salt/.password")
ACTION="state.sls"
STATE="system_description"

if [[ "$1" == "--dry-run" ]]; then
  echo "--- Running in test mode (no changes will be applied) ---"
  $SUDO_CMD python3.14 /var/home/neg/src/salt/run_salt.py \
    --config-dir="${CONFIG_DIR}" \
    -l info \
    --local ${ACTION} ${STATE} test=True
else
  echo "SUDO_PASS=$SUDO_PASS"
  echo "--- Applying configuration ---"
  echo "$SUDO_PASS" | sudo -S -E python3.14 /var/home/neg/src/salt/run_salt.py \
    --config-dir="${CONFIG_DIR}" \
    -l info \
    --local ${ACTION} ${STATE}
fi