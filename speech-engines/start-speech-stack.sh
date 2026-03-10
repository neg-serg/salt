#!/usr/bin/env bash
# Start all speech services and verify health
set -euo pipefail

source "$(dirname "$0")/common.sh"

log "=== Starting Speech Stack ==="

# Start Piper (CPU fallback, always available)
log "Starting piper-tts..."
systemctl --user start piper-tts.service 2>/dev/null || warn "piper-tts.service not installed"

# Start Chatterbox (GPU primary)
log "Starting chatterbox-tts (may take 30-60s to load model)..."
systemctl --user start chatterbox-tts.service 2>/dev/null || warn "chatterbox-tts.service not installed"

# Wait for health
log "Waiting for services..."

# Piper should be fast
for i in $(seq 1 10); do
    if curl -sf http://127.0.0.1:8001/v1/models >/dev/null 2>&1; then
        log "Piper TTS: ready (port 8001)"
        break
    fi
    sleep 1
done

# Chatterbox takes longer (model loading)
for i in $(seq 1 60); do
    if curl -sf http://127.0.0.1:8000/v1/models >/dev/null 2>&1; then
        log "Chatterbox TTS: ready (port 8000)"
        break
    fi
    if [[ $i -eq 60 ]]; then
        warn "Chatterbox TTS: not ready after 60s — check: journalctl --user -u chatterbox-tts -n 20"
    fi
    sleep 1
done

# Check whisper-cli
if command -v whisper-cli &>/dev/null; then
    log "whisper-cli: available ($(which whisper-cli))"
else
    warn "whisper-cli: not found on PATH"
fi

# Status summary
log "=== Speech Stack Status ==="
systemctl --user status chatterbox-tts.service --no-pager 2>/dev/null | head -3 || echo "  chatterbox-tts: not installed"
systemctl --user status piper-tts.service --no-pager 2>/dev/null | head -3 || echo "  piper-tts: not installed"
