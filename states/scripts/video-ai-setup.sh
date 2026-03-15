#!/bin/bash
# Bootstrap ComfyUI with ROCm PyTorch for video generation on AMD 7900 XTX.
# Idempotent: skips steps if venv already exists and is functional.
# Environment: COMFYUI_DIR (required) — installation target directory.
set -euo pipefail

: "${COMFYUI_DIR:?COMFYUI_DIR must be set}"

VENV_DIR="${COMFYUI_DIR}/venv"
ROCM_TORCH_INDEX="https://download.pytorch.org/whl/rocm6.4"

# ── Clone ComfyUI if not present ─────────────────────────────────────
if [[ ! -d "${COMFYUI_DIR}/.git" ]]; then
    echo "[video-ai] Cloning ComfyUI..."
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
else
    echo "[video-ai] ComfyUI already cloned, pulling updates..."
    git -C "${COMFYUI_DIR}" pull --ff-only || true
fi

# ── Create venv if not present ───────────────────────────────────────
if [[ ! -f "${VENV_DIR}/bin/python" ]]; then
    echo "[video-ai] Creating Python venv..."
    python3 -m venv "${VENV_DIR}"
fi

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"

# ── Install PyTorch with ROCm support ────────────────────────────────
if ! python -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
    echo "[video-ai] Installing PyTorch ROCm..."
    pip install --upgrade pip wheel setuptools
    pip install torch torchvision torchaudio --index-url "${ROCM_TORCH_INDEX}"
else
    echo "[video-ai] PyTorch ROCm already installed and functional"
fi

# ── Install ComfyUI requirements ─────────────────────────────────────
echo "[video-ai] Installing ComfyUI requirements..."
pip install -r "${COMFYUI_DIR}/requirements.txt"

# ── Install flash-attention (AMD ROCm fork) ──────────────────────────
if ! python -c "import flash_attn" 2>/dev/null; then
    echo "[video-ai] Installing flash-attention (AMD ROCm fork)..."
    pip install flash-attn --no-build-isolation 2>/dev/null || {
        echo "[video-ai] WARNING: flash-attn install failed (optional, ~30% speedup)"
        echo "[video-ai] You can retry manually: ${VENV_DIR}/bin/pip install flash-attn --no-build-isolation"
    }
else
    echo "[video-ai] flash-attention already installed"
fi

echo "[video-ai] Setup complete. ComfyUI ready at ${COMFYUI_DIR}"
echo "[video-ai] PyTorch ROCm: $(python -c 'import torch; print(torch.__version__)')"
echo "[video-ai] CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())')"
