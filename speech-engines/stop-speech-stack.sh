#!/usr/bin/env bash
# Stop all speech services and report freed resources
set -euo pipefail

source "$(dirname "$0")/common.sh"

log "=== Stopping Speech Stack ==="

# Stop Chatterbox (frees GPU VRAM)
if systemctl --user is-active chatterbox-tts.service &>/dev/null; then
    systemctl --user stop chatterbox-tts.service
    log "Stopped chatterbox-tts (freed ~8GB VRAM)"
else
    log "chatterbox-tts already stopped"
fi

# Stop Piper
if systemctl --user is-active piper-tts.service &>/dev/null; then
    systemctl --user stop piper-tts.service
    log "Stopped piper-tts"
else
    log "piper-tts already stopped"
fi

log "=== Speech Stack stopped ==="

# Show VRAM status if rocm-smi available
if command -v rocm-smi &>/dev/null; then
    rocm-smi --showmeminfo vram 2>/dev/null | grep -E "(Total|Used)" || true
fi
