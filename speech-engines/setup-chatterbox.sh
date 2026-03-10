#!/usr/bin/env bash
# Install Chatterbox-TTS-Server with ROCm support
# Provides OpenAI-compatible /v1/audio/speech endpoint on port 8000
set -euo pipefail

source "$(dirname "$0")/common.sh"

CHATTERBOX_DIR="$SCRIPT_DIR/chatterbox-server"
VENV_DIR="$SCRIPT_DIR/.venv-chatterbox"

log "=== Chatterbox TTS Server Setup ==="

# Check prerequisites
check_command python3 "Install Python 3.10-3.12"
check_command git "Install git"

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
log "Python version: $PYTHON_VERSION"

# Python 3.14 won't have ROCm PyTorch wheels — check for 3.12 or 3.11
if [[ "$PYTHON_VERSION" == "3.14" || "$PYTHON_VERSION" == "3.13" ]]; then
    if command -v python3.12 &>/dev/null; then
        PYTHON_BIN=python3.12
        log "Using python3.12 for PyTorch ROCm compatibility"
    elif command -v python3.11 &>/dev/null; then
        PYTHON_BIN=python3.11
        log "Using python3.11 for PyTorch ROCm compatibility"
    else
        warn "Python $PYTHON_VERSION detected. PyTorch ROCm wheels may not be available."
        warn "Consider installing python3.12: pacman -S python312 (AUR) or pyenv install 3.12"
        PYTHON_BIN=python3
    fi
else
    PYTHON_BIN=python3
fi

# Clone Chatterbox-TTS-Server
if [[ -d "$CHATTERBOX_DIR" ]]; then
    log "Chatterbox-TTS-Server already cloned: $CHATTERBOX_DIR"
    cd "$CHATTERBOX_DIR"
    git pull --ff-only 2>/dev/null || true
else
    log "Cloning Chatterbox-TTS-Server..."
    git clone https://github.com/devnen/Chatterbox-TTS-Server.git "$CHATTERBOX_DIR"
    cd "$CHATTERBOX_DIR"
fi

# Create venv
setup_venv "$VENV_DIR"

# Install PyTorch with ROCm
log "Installing PyTorch with ROCm support..."
# Try latest ROCm index first, fall back to older ones
if ! pip install torch torchaudio --index-url https://download.pytorch.org/whl/rocm6.2.4 2>/dev/null; then
    log "ROCm 6.2.4 wheels not available, trying nightly..."
    pip install --pre torch torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm6.2.4
fi

# Install numpy first (avoids build isolation issues with old setuptools)
log "Installing numpy..."
pip install "numpy>=1.24.0,<2.0"

# Install server dependencies (before chatterbox-tts to avoid build failures)
log "Installing server dependencies..."
pip install setuptools wheel meson-python meson ninja
pip install descript-audio-codec
pip install fastapi "uvicorn[standard]" soundfile huggingface_hub \
    safetensors pydantic python-dotenv \
    Jinja2 python-multipart requests PyYAML tqdm pydub audiotsm \
    praat-parselmouth librosa hf-transfer \
    transformers tokenizers accelerate \
    resemble-perth s3tokenizer omegaconf conformer \
    vector_quantize_pytorch diffusers pandas watchdog unidecode inflect

# Install chatterbox engine (devnen's fork, --no-deps to avoid torch version conflicts)
log "Installing Chatterbox TTS engine..."
pip install --no-deps "chatterbox-tts @ git+https://github.com/devnen/chatterbox-v2.git@master"

# Pre-download model (optional — happens automatically on first request)
log "Pre-downloading Chatterbox model (this may take a while)..."
python -c "
from huggingface_hub import snapshot_download
snapshot_download('ResembleAI/chatterbox', local_dir=None)
print('Model cached successfully.')
" 2>/dev/null || warn "Model pre-download failed — will download on first request"

log "=== Chatterbox TTS Server setup complete ==="
log "To start: source $VENV_DIR/bin/activate && cd $CHATTERBOX_DIR && python server.py"
log "Endpoint: http://127.0.0.1:8000/v1/audio/speech"
