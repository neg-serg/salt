#!/bin/bash
# Apply system_description salt state with full logging
set -uo pipefail

SALT_DIR="/var/home/neg/src/salt"
VENV="${SALT_DIR}/.venv"
CONFIG_DIR="${SALT_DIR}/salt_config"
LOG_DIR="${SALT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/system_description-${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

echo "=== Applying system_description ($(date)) ==="
echo "Log: ${LOG_FILE}"

sudo -E "${VENV}/bin/python3" "${SALT_DIR}/run_salt.py" \
    --config-dir="${CONFIG_DIR}" \
    --local \
    --log-level=info \
    --log-file="${LOG_FILE}" \
    --log-file-level=debug \
    state.sls system_description 2>&1 | tee -a "${LOG_FILE}"

RC=${PIPESTATUS[0]}
echo ""
echo "=== Finished (exit code: ${RC}) at $(date) ==="
echo "Full log: ${LOG_FILE}"
exit $RC
