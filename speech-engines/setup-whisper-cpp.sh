#!/usr/bin/env bash
# Build whisper.cpp with HIPBLAS (ROCm) support and install whisper-cli
set -euo pipefail

source "$(dirname "$0")/common.sh"

WHISPER_DIR="$SCRIPT_DIR/whisper.cpp"
INSTALL_DIR="$HOME/.local/bin"
MODEL_DIR="$VOICES_DIR"
MODEL_NAME="ggml-large-v3-turbo.bin"

log "=== whisper.cpp Setup (HIPBLAS/ROCm) ==="

# Check prerequisites
check_command cmake "Install cmake"
check_command make "Install make or build-essential"
check_command git "Install git"

# Check for HIP compiler
if ! command -v hipcc &>/dev/null; then
    warn "hipcc not found. ROCm SDK required for GPU build."
    warn "On Arch: pacman -S rocm-hip-sdk rocm-opencl-sdk"
    warn "Will attempt CPU-only build as fallback."
    USE_HIP=0
else
    USE_HIP=1
    log "HIP compiler found: $(hipcc --version 2>/dev/null | head -1)"
fi

# Clone whisper.cpp
if [[ -d "$WHISPER_DIR" ]]; then
    log "whisper.cpp already cloned: $WHISPER_DIR"
    cd "$WHISPER_DIR"
    git pull --ff-only 2>/dev/null || true
else
    log "Cloning whisper.cpp..."
    git clone https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
    cd "$WHISPER_DIR"
fi

# Build
mkdir -p build && cd build

if [[ "$USE_HIP" -eq 1 ]]; then
    log "Building with HIPBLAS (ROCm) support for gfx1100..."
    export LIBRARY_PATH="/opt/rocm/lib:${LIBRARY_PATH:-}"
    cmake .. \
        -DGGML_HIP=ON \
        -DCMAKE_HIP_ARCHITECTURES="gfx1100" \
        -DCMAKE_C_COMPILER=/opt/rocm/bin/amdclang \
        -DCMAKE_CXX_COMPILER=/opt/rocm/bin/hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOME/.local"
else
    log "Building CPU-only (no ROCm detected)..."
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOME/.local"
fi

cmake --build . --target whisper-cli --config Release -j "$(nproc)"

# Install
log "Installing whisper-cli to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp bin/whisper-cli "$INSTALL_DIR/" 2>/dev/null || cp bin/main "$INSTALL_DIR/whisper-cli" 2>/dev/null || error "No whisper-cli binary found in build output"
chmod +x "$INSTALL_DIR/whisper-cli"

# Verify
if [[ -x "$INSTALL_DIR/whisper-cli" ]]; then
    log "whisper-cli installed: $INSTALL_DIR/whisper-cli"
else
    error "Failed to install whisper-cli"
fi

# Ensure ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    warn "$INSTALL_DIR is not in PATH. Add to your shell profile:"
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Download model
log "Downloading Whisper large-v3-turbo model (~1.5GB)..."
cd "$WHISPER_DIR"
if [[ -f "$MODEL_DIR/$MODEL_NAME" ]]; then
    log "Model already exists: $MODEL_DIR/$MODEL_NAME"
else
    # Use whisper.cpp's download script if available
    if [[ -f models/download-ggml-model.sh ]]; then
        bash models/download-ggml-model.sh large-v3-turbo
        mv models/ggml-large-v3-turbo.bin "$MODEL_DIR/" 2>/dev/null || true
    else
        download_model \
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_NAME" \
            "$MODEL_DIR/$MODEL_NAME"
    fi
fi

# Quick test
if [[ -f "$MODEL_DIR/$MODEL_NAME" ]]; then
    log "Testing whisper-cli..."
    # Generate a short test WAV (1 second of silence)
    python3 -c "
import wave, struct
with wave.open('/tmp/whisper_test.wav', 'w') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(16000)
    w.writeframes(struct.pack('<' + 'h' * 16000, *([0] * 16000)))
" 2>/dev/null || true

    if [[ -f /tmp/whisper_test.wav ]]; then
        "$INSTALL_DIR/whisper-cli" -m "$MODEL_DIR/$MODEL_NAME" -f /tmp/whisper_test.wav --no-prints 2>/dev/null && \
            log "whisper-cli test passed" || \
            warn "whisper-cli test produced warnings (may still work)"
        rm -f /tmp/whisper_test.wav
    fi
fi

log "=== whisper.cpp setup complete ==="
log "Binary: $INSTALL_DIR/whisper-cli"
log "Model: $MODEL_DIR/$MODEL_NAME"
log "Usage: whisper-cli -m $MODEL_DIR/$MODEL_NAME -f input.wav -l auto"
