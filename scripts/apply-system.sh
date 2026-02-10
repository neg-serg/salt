#!/bin/bash
# Apply system_description salt state with full logging
set -uo pipefail

SALT_DIR="/var/home/neg/src/salt"
VENV="${SALT_DIR}/.venv/bin"
LOG_DIR="${SALT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/system_description-${TIMESTAMP}.log"

mkdir -p "${LOG_DIR}"

echo "=== Applying system_description ($(date)) ==="
echo "Log: ${LOG_FILE}"

sudo "${VENV}/salt-call" --local \
    --file-root="${SALT_DIR}/states" \
    --log-level=info \
    --log-file="${LOG_FILE}" \
    --log-file-level=debug \
    state.apply system_description 2>&1 | tee -a "${LOG_FILE}"

RC=${PIPESTATUS[0]}
echo ""
echo "=== Finished (exit code: ${RC}) at $(date) ==="
echo "Full log: ${LOG_FILE}"
exit $RC
