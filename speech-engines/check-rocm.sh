#!/usr/bin/env bash
# Check ROCm environment and GPU availability for speech engines
set -euo pipefail

source "$(dirname "$0")/common.sh"

log "Checking ROCm environment..."

# Check rocm-smi
if ! command -v rocm-smi &>/dev/null; then
    error "rocm-smi not found. Install ROCm 6.x first."
fi

# Check GPU
GPU_INFO=$(rocm-smi --showproductname 2>/dev/null | grep -i "card" || true)
if [[ -z "$GPU_INFO" ]]; then
    error "No AMD GPU detected by rocm-smi."
fi
log "GPU detected: $GPU_INFO"

# Check gfx version
GFX_VERSION=$(rocm-smi --showgpuid 2>/dev/null | grep -oP 'gfx\d+' | head -1 || true)
if [[ -z "$GFX_VERSION" ]]; then
    # Fallback: check via /sys
    GFX_VERSION=$(cat /sys/class/drm/card*/device/ip_discovery/die/*/GC/*/major_minor 2>/dev/null | head -1 || echo "unknown")
    log "GFX version (fallback): $GFX_VERSION"
else
    log "GFX version: $GFX_VERSION"
fi

# Check VRAM
VRAM_INFO=$(rocm-smi --showmeminfo vram 2>/dev/null || true)
if [[ -n "$VRAM_INFO" ]]; then
    log "VRAM info:"
    echo "$VRAM_INFO" | grep -E "(Total|Used)" | while read -r line; do
        log "  $line"
    done
fi

# Check PyTorch ROCm
if command -v python3 &>/dev/null; then
    TORCH_CHECK=$(python3 -c "
import torch
print(f'PyTorch {torch.__version__}')
print(f'ROCm available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'Device: {torch.cuda.get_device_name(0)}')
    print(f'VRAM: {torch.cuda.get_device_properties(0).total_mem / 1024**3:.1f} GB')
" 2>/dev/null || echo "PyTorch not installed or ROCm not available")
    log "PyTorch status: $TORCH_CHECK"
fi

# Check HIP compiler (needed for whisper.cpp)
if command -v hipcc &>/dev/null; then
    HIP_VERSION=$(hipcc --version 2>/dev/null | head -1 || echo "unknown")
    log "HIP compiler: $HIP_VERSION"
else
    warn "hipcc not found — needed to build whisper.cpp with HIPBLAS"
fi

log "ROCm check complete."
