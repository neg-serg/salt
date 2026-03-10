#!/usr/bin/env bash
# Install Piper TTS as CPU fallback with OpenAI-compatible API
# Uses piper-tts-http-server for /v1/audio/speech on port 8001
set -euo pipefail

source "$(dirname "$0")/common.sh"

VENV_DIR="$SCRIPT_DIR/.venv-piper"
PIPER_VOICES_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main"

log "=== Piper TTS Setup ==="

check_command python3 "Install Python 3.10+"

# Create venv
setup_venv "$VENV_DIR"

# Install piper-tts and dependencies
log "Installing piper-tts..."
pip install piper-tts pathvalidate

# Install FastAPI server for OpenAI-compatible API (piper-server.py)
log "Installing server dependencies..."
pip install fastapi "uvicorn[standard]"

# Download voice models
log "Downloading English voice (en_US-lessac-medium)..."
download_model \
    "$PIPER_VOICES_URL/en/en_US/lessac/medium/en_US-lessac-medium.onnx" \
    "$VOICES_DIR/en_US-lessac-medium.onnx"
download_model \
    "$PIPER_VOICES_URL/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json" \
    "$VOICES_DIR/en_US-lessac-medium.onnx.json"

log "Downloading Russian voice (ru_RU-irina-medium)..."
download_model \
    "$PIPER_VOICES_URL/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx" \
    "$VOICES_DIR/ru_RU-irina-medium.onnx"
download_model \
    "$PIPER_VOICES_URL/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx.json" \
    "$VOICES_DIR/ru_RU-irina-medium.onnx.json"

# Quick test
log "Testing piper-tts..."
echo "Hello, this is a test." | piper --model "$VOICES_DIR/en_US-lessac-medium.onnx" --output_file /tmp/piper_test.wav 2>/dev/null
if [[ -f /tmp/piper_test.wav ]]; then
    log "Piper test passed: /tmp/piper_test.wav generated ($(du -h /tmp/piper_test.wav | cut -f1))"
    rm -f /tmp/piper_test.wav
else
    warn "Piper test failed — check installation"
fi

log "=== Piper TTS setup complete ==="
log "To start server: source $VENV_DIR/bin/activate && python $SCRIPT_DIR/piper-server.py --port 8001 --voices-dir $VOICES_DIR"
log "Endpoint: http://127.0.0.1:8001/v1/audio/speech"
