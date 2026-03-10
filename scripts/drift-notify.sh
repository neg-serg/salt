#!/usr/bin/env bash
# drift-notify.sh — run pkg-drift and notify on drift detected
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/drift-$(date +%F).log"

mkdir -p "$LOG_DIR"

# Run drift check; exit 0 = clean, exit 1 = drift detected
if "${SCRIPT_DIR}/pkg-drift.zsh" > "$LOG_FILE" 2>&1; then
    exit 0
fi

# Drift detected — send desktop notification
if command -v notify-send &>/dev/null; then
    notify-send --urgency=normal \
        "Salt Drift" \
        "Package drift detected. Run: just drift-check\nSee: ${LOG_FILE}"
fi

echo "Drift detected. Report: ${LOG_FILE}" >&2
exit 1
