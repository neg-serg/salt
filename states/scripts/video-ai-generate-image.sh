#!/bin/bash
# shellcheck disable=SC2034,SC1091  # vars used by sourced lib-comfyui.sh
# Image generation runner: submit workflow to ComfyUI, collect output PNGs.
# Usage: video-ai-generate-image.sh --model MODEL --prompt "TEXT" [OPTIONS]
set -euo pipefail

VIDEO_AI_DIR="${VIDEO_AI_DIR:-/mnt/one/video-ai}"
COMFYUI_DIR="${COMFYUI_DIR:-${VIDEO_AI_DIR}/comfyui}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
COMFYUI_URL="http://127.0.0.1:${COMFYUI_PORT}"
IMAGES_DIR="${VIDEO_AI_DIR}/images"
WORKFLOWS_DIR="${VIDEO_AI_DIR}/workflows"
VENV_PYTHON="${COMFYUI_DIR}/venv/bin/python"
COMFYUI_OUTPUT="${VIDEO_AI_DIR}/comfyui-output"

# ── Defaults ─────────────────────────────────────────────────────────
MODEL=""
PROMPT=""
NEG_PROMPT="worst quality, blurry, distorted, low resolution, watermark"
IMAGE=""
WIDTH=1152
HEIGHT=1152
STEPS=26
CFG=3.8
SEED=0
COUNT=1
STRENGTH=0.7

usage() {
    cat >&2 <<'EOF'
Usage: video-ai-generate-image.sh --model ID --prompt "TEXT" [OPTIONS]

Options:
  --model ID          Model ID (e.g., chroma-hd)
  --prompt TEXT        Text description for image generation
  --neg-prompt TEXT    Negative prompt (default: quality filters)
  --image PATH         Reference image for img2img (optional)
  --width W            Output width (default: 1152)
  --height H           Output height (default: 1152)
  --steps N            Sampling steps (default: 26)
  --cfg FLOAT          CFG scale (default: 3.8)
  --seed N             Random seed (default: random)
  --count N            Number of images (default: 1)
  --strength FLOAT     i2i denoising strength (default: 0.7)
  --help               Show this help
EOF
    exit 1
}

# ── Parse arguments ──────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)      MODEL="$2"; shift 2 ;;
        --prompt)     PROMPT="$2"; shift 2 ;;
        --neg-prompt) NEG_PROMPT="$2"; shift 2 ;;
        --image)      IMAGE="$2"; shift 2 ;;
        --width)      WIDTH="$2"; shift 2 ;;
        --height)     HEIGHT="$2"; shift 2 ;;
        --steps)      STEPS="$2"; shift 2 ;;
        --cfg)        CFG="$2"; shift 2 ;;
        --seed)       SEED="$2"; shift 2 ;;
        --count)      COUNT="$2"; shift 2 ;;
        --strength)   STRENGTH="$2"; shift 2 ;;
        --help)       usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

[[ -z "${MODEL}" ]] && { echo "Error: --model is required" >&2; usage; }
[[ -z "${PROMPT}" ]] && { echo "Error: --prompt is required" >&2; usage; }

# ── Validate prerequisites ───────────────────────────────────────────
[[ -f "${VENV_PYTHON}" ]] || { echo "Error: ComfyUI not installed at ${COMFYUI_DIR}" >&2; exit 4; }

# ── Resolve model file ───────────────────────────────────────────────
MODEL_FILE=""
DIFFUSION_DIR="${COMFYUI_DIR}/models/diffusion_models"
# Search by model prefix (strip numeric suffix: chroma-hd → chroma)
MODEL_PREFIX="${MODEL%%[-_]*}"
if [[ -d "${DIFFUSION_DIR}" ]]; then
    MODEL_FILE=$(find -L "${DIFFUSION_DIR}" -maxdepth 1 -name "*.safetensors" \
        -iname "*${MODEL_PREFIX}*" -printf "%f\n" 2>/dev/null | head -1)
fi
[[ -n "${MODEL_FILE}" ]] || { echo "Error: No model file found for '${MODEL}' (prefix: ${MODEL_PREFIX}) in ${DIFFUSION_DIR}" >&2; exit 2; }
echo "[image-gen] Model file: ${MODEL_FILE}" >&2

# ── Select workflow ─────────────────────────────────────────────────
WORKFLOW_FILE="${WORKFLOWS_DIR}/${MODEL}.json"
if [[ -n "${IMAGE}" ]]; then
    # Try i2i workflow
    for wf in "${WORKFLOWS_DIR}/"*i2i*.json; do
        [[ -f "$wf" ]] || continue
        if [[ "$(basename "$wf" .json)" == *"${MODEL%%[-_]*}"* ]]; then
            WORKFLOW_FILE="$wf"
            echo "[image-gen] Using i2i workflow: $(basename "${WORKFLOW_FILE}")" >&2
            break
        fi
    done
else
    # Try t2i workflow
    for wf in "${WORKFLOWS_DIR}/"*t2i*.json; do
        [[ -f "$wf" ]] || continue
        if [[ "$(basename "$wf" .json)" == *"${MODEL%%[-_]*}"* ]]; then
            WORKFLOW_FILE="$wf"
            break
        fi
    done
fi
[[ -f "${WORKFLOW_FILE}" ]] || { echo "Error: No workflow found for model '${MODEL}'" >&2; exit 2; }

if [[ -n "${IMAGE}" ]]; then
    [[ -f "${IMAGE}" ]] || { echo "Error: Image file not found: ${IMAGE}" >&2; exit 1; }
    IMAGE="$(realpath "${IMAGE}")"
    mkdir -p "${COMFYUI_DIR}/input"
    cp "${IMAGE}" "${COMFYUI_DIR}/input/input_image.png"
fi

# ── Start ComfyUI if not running ─────────────────────────────────────
# shellcheck source=lib-comfyui.sh
source "$(dirname "$0")/lib-comfyui.sh"
comfyui_start "image-gen" "${IMAGES_DIR}"

# ── Generate images ──────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SLUG=$(echo "${PROMPT}" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | head -c 40 | sed 's/-$//')
GENERATED_FILES=()

for (( n=0; n<COUNT; n++ )); do
    CURRENT_SEED=$(( SEED + n ))
    WORK_DIR=$(mktemp -d "/tmp/image-gen-${MODEL}-XXXXXX")
    WORKFLOW_RESOLVED="${WORK_DIR}/workflow.json"

    # Substitute placeholders in workflow
    sed -e "s|__PROMPT__|${PROMPT//|/\\|}|g" \
        -e "s|__NEG_PROMPT__|${NEG_PROMPT//|/\\|}|g" \
        -e "s|__MODEL_FILE__|${MODEL_FILE}|g" \
        -e "s|__WIDTH__|${WIDTH}|g" \
        -e "s|__HEIGHT__|${HEIGHT}|g" \
        -e "s|__STEPS__|${STEPS}|g" \
        -e "s|__CFG__|${CFG}|g" \
        -e "s|__SEED__|${CURRENT_SEED}|g" \
        -e "s|__STRENGTH__|${STRENGTH}|g" \
        "${WORKFLOW_FILE}" > "${WORKFLOW_RESOLVED}"

    echo "[image-gen] Generating image $((n+1))/${COUNT} (seed: ${CURRENT_SEED})..." >&2

    comfyui_submit "image-gen" "${WORKFLOW_RESOLVED}"
    comfyui_poll "image-gen"

    # Collect output PNG
    OUTPUT_PNG=$(find "${COMFYUI_OUTPUT}" -name "*.png" -newer "${WORKFLOW_RESOLVED}" 2>/dev/null | sort | tail -1)
    if [[ -z "${OUTPUT_PNG}" ]]; then
        OUTPUT_PNG=$(find "${COMFYUI_OUTPUT}" -name "*.png" 2>/dev/null | sort | tail -1)
    fi

    if [[ -n "${OUTPUT_PNG}" ]]; then
        SUFFIX=""
        (( COUNT > 1 )) && SUFFIX="_$((n+1))"
        DEST="${IMAGES_DIR}/${MODEL}_${TIMESTAMP}_${SLUG}${SUFFIX}.png"
        mv "${OUTPUT_PNG}" "${DEST}"
        GENERATED_FILES+=("${DEST}")
        echo "[image-gen] Saved: ${DEST}" >&2
    else
        echo "[image-gen] Warning: No output PNG found for image $((n+1))" >&2
    fi

    # Clean up ComfyUI output and temp
    rm -rf "${COMFYUI_OUTPUT:?}"/* "${WORK_DIR}"
done

# ── Report ───────────────────────────────────────────────────────────
echo "[image-gen] Done: ${#GENERATED_FILES[@]} image(s) generated" >&2
for f in "${GENERATED_FILES[@]}"; do
    echo "${f}"
done
