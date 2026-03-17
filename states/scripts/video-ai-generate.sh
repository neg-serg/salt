#!/bin/bash
# Video AI generation runner: submit workflow to ComfyUI, encode output as MP4.
# Usage: video-ai-generate.sh --model MODEL_ID --prompt "TEXT" [--image PATH] [--compat]
#        [--width W] [--height H] [--frames N]
set -euo pipefail

VIDEO_AI_DIR="${VIDEO_AI_DIR:-/mnt/one/video-ai}"
COMFYUI_DIR="${COMFYUI_DIR:-${VIDEO_AI_DIR}/comfyui}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
COMFYUI_URL="http://127.0.0.1:${COMFYUI_PORT}"
OUTPUT_DIR="${VIDEO_AI_DIR}/output"
WORKFLOWS_DIR="${VIDEO_AI_DIR}/workflows"
VENV_PYTHON="${COMFYUI_DIR}/venv/bin/python"

# ── Defaults ─────────────────────────────────────────────────────────
MODEL=""
PROMPT=""
IMAGE=""
WIDTH=854
HEIGHT=480
FRAMES=97  # ~4 seconds at 24fps
COMPAT=false

usage() {
    cat >&2 <<'EOF'
Usage: video-ai-generate.sh --model ID --prompt "TEXT" [OPTIONS]

Options:
  --model ID      Model ID (e.g., ltx-video-2b, wan21-t2v-14b)
  --prompt TEXT    Text description for video generation
  --image PATH    Reference image for image-to-video (optional)
  --width W       Output width (default: 854)
  --height H      Output height (default: 480)
  --frames N      Number of frames (default: 97, ~4s at 24fps)
  --compat        Encode as H.264 instead of H.265
  --help          Show this help
EOF
    exit 1
}

# ── Parse arguments ──────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)  MODEL="$2"; shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --image)  IMAGE="$2"; shift 2 ;;
        --width)  WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        --frames) FRAMES="$2"; shift 2 ;;
        --compat) COMPAT=true; shift ;;
        --help)   usage ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

[[ -z "${MODEL}" ]] && { echo "Error: --model is required" >&2; usage; }
[[ -z "${PROMPT}" ]] && { echo "Error: --prompt is required" >&2; usage; }

# ── Validate prerequisites ───────────────────────────────────────────
[[ -f "${VENV_PYTHON}" ]] || { echo "Error: ComfyUI not installed at ${COMFYUI_DIR}" >&2; exit 4; }
command -v ffmpeg >/dev/null || { echo "Error: ffmpeg not found" >&2; exit 4; }

WORKFLOW_FILE="${WORKFLOWS_DIR}/${MODEL}.json"
# Try model-specific workflow, fall back to generic t2v workflow
if [[ ! -f "${WORKFLOW_FILE}" ]]; then
    # Extract model family prefix (e.g. "ltx" from "ltx-video-2b")
    MODEL_PREFIX="${MODEL%%[-_]*}"
    # Prefer t2v workflow for text-to-video (default mode)
    for suffix in t2v ""; do
        for wf in "${WORKFLOWS_DIR}"/*"${suffix}"*; do
            [[ -f "$wf" ]] || continue
            if [[ "$(basename "$wf" .json)" == *"${MODEL_PREFIX}"* ]]; then
                WORKFLOW_FILE="$wf"
                break 2
            fi
        done
    done
fi
[[ -f "${WORKFLOW_FILE}" ]] || { echo "Error: No workflow found for model '${MODEL}'" >&2; exit 2; }

if [[ -n "${IMAGE}" ]]; then
    [[ -f "${IMAGE}" ]] || { echo "Error: Image file not found: ${IMAGE}" >&2; exit 1; }
    IMAGE="$(realpath "${IMAGE}")"

    # Switch to i2v workflow variant when image is provided
    I2V_FILE="${WORKFLOW_FILE//-t2v/-i2v}"
    if [[ "${I2V_FILE}" != "${WORKFLOW_FILE}" && -f "${I2V_FILE}" ]]; then
        WORKFLOW_FILE="${I2V_FILE}"
        echo "[video-ai] Using i2v workflow: $(basename "${WORKFLOW_FILE}")" >&2
    else
        echo "[video-ai] Warning: no i2v workflow found, using default (image may be ignored)" >&2
    fi
fi

# ── Resolve checkpoint name ───────────────────────────────────────────
# Find the checkpoint file relative to ComfyUI's checkpoints dir
CKPT_DIR="${COMFYUI_DIR}/models/checkpoints"
CKPT_NAME=""
if [[ -d "${CKPT_DIR}/${MODEL}" || -L "${CKPT_DIR}/${MODEL}" ]]; then
    CKPT_NAME=$(find -L "${CKPT_DIR}/${MODEL}" -maxdepth 2 \
        \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.gguf" \) -printf "%P\n" 2>/dev/null | head -1)
    [[ -n "${CKPT_NAME}" ]] && CKPT_NAME="${MODEL}/${CKPT_NAME}"
fi
if [[ -z "${CKPT_NAME}" ]]; then
    # Fallback: search all checkpoints for model name
    CKPT_NAME=$(find -L "${CKPT_DIR}" -maxdepth 3 \
        \( -name "*.safetensors" -o -name "*.ckpt" -o -name "*.gguf" \) -printf "%P\n" 2>/dev/null \
        | grep -i "${MODEL}" | head -1 || true)
fi
[[ -n "${CKPT_NAME}" ]] || { echo "Error: No checkpoint found for model '${MODEL}'" >&2; exit 2; }
echo "[video-ai] Checkpoint: ${CKPT_NAME}" >&2

# ── Prepare workflow ─────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SLUG=$(echo "${PROMPT}" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | head -c 40 | sed 's/-$//')
WORK_DIR=$(mktemp -d "/tmp/video-ai-${MODEL}-XXXXXX")
WORKFLOW_RESOLVED="${WORK_DIR}/workflow.json"

# Substitute placeholders in workflow
sed -e "s|__PROMPT__|${PROMPT//|/\\|}|g" \
    -e "s|__CKPT_NAME__|${CKPT_NAME}|g" \
    -e "s|__WIDTH__|${WIDTH}|g" \
    -e "s|__HEIGHT__|${HEIGHT}|g" \
    -e "s|__FRAMES__|${FRAMES}|g" \
    "${WORKFLOW_FILE}" > "${WORKFLOW_RESOLVED}"

# If image provided, inject into workflow
if [[ -n "${IMAGE}" ]]; then
    # Create input image link for ComfyUI
    mkdir -p "${COMFYUI_DIR}/input"
    cp "${IMAGE}" "${COMFYUI_DIR}/input/input_image.png"
fi

echo "[video-ai] Model: ${MODEL}" >&2
echo "[video-ai] Prompt: ${PROMPT}" >&2
echo "[video-ai] Resolution: ${WIDTH}x${HEIGHT}, Frames: ${FRAMES}" >&2

# ── Start ComfyUI if not running ─────────────────────────────────────
COMFYUI_OUTPUT="${VIDEO_AI_DIR}/comfyui-output"
mkdir -p "${COMFYUI_OUTPUT}"
COMFYUI_PID=""
if ! curl -sf "${COMFYUI_URL}/system_stats" >/dev/null 2>&1; then
    echo "[video-ai] Starting ComfyUI on port ${COMFYUI_PORT}..." >&2
    cd "${COMFYUI_DIR}"
    "${VENV_PYTHON}" main.py \
        --listen 127.0.0.1 \
        --port "${COMFYUI_PORT}" \
        --disable-auto-launch \
        --output-directory "${COMFYUI_OUTPUT}" \
        >/dev/null 2>&1 &
    COMFYUI_PID=$!

    # Wait for ComfyUI to become ready
    echo -n "[video-ai] Waiting for ComfyUI..." >&2
    for i in $(seq 1 120); do
        if curl -sf "${COMFYUI_URL}/system_stats" >/dev/null 2>&1; then
            echo " ready (${i}s)" >&2
            break
        fi
        if [[ $i -eq 120 ]]; then
            echo " timeout!" >&2
            kill "${COMFYUI_PID}" 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done
fi

# ── Submit workflow ──────────────────────────────────────────────────
echo "[video-ai] Submitting workflow..." >&2
RESPONSE=$(curl -sf -X POST "${COMFYUI_URL}/prompt" \
    -H "Content-Type: application/json" \
    -d @"${WORKFLOW_RESOLVED}")

PROMPT_ID=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['prompt_id'])" 2>/dev/null || true)

if [[ -z "${PROMPT_ID}" ]]; then
    echo "Error: Failed to submit workflow to ComfyUI" >&2
    echo "Response: ${RESPONSE}" >&2
    [[ -n "${COMFYUI_PID}" ]] && kill "${COMFYUI_PID}" 2>/dev/null || true
    exit 1
fi

echo "[video-ai] Prompt ID: ${PROMPT_ID}" >&2

# ── Poll for progress ────────────────────────────────────────────────
echo "[video-ai] Generating..." >&2
while true; do
    HISTORY=$(curl -sf "${COMFYUI_URL}/history/${PROMPT_ID}" 2>/dev/null || echo "{}")

    # Check if complete or errored
    POLL_RESULT=$(echo "${HISTORY}" | python3 -c "
import sys, json
h = json.load(sys.stdin)
if '${PROMPT_ID}' in h:
    st = h['${PROMPT_ID}'].get('status', {})
    if st.get('completed', False) or st.get('status_str') == 'success':
        print('DONE')
    elif st.get('status_str') == 'error':
        for msg in st.get('messages', []):
            if msg[0] == 'execution_error':
                print('ERROR:' + msg[1].get('exception_message', 'Unknown error'))
                break
        else:
            print('ERROR:unknown')
    else:
        print('RUNNING')
else:
    print('RUNNING')
" 2>/dev/null || echo "RUNNING")

    if [[ "${POLL_RESULT}" == "DONE" ]]; then
        echo -e "\n[video-ai] Generation complete!" >&2
        break
    elif [[ "${POLL_RESULT}" == ERROR:* ]]; then
        echo -e "\n[video-ai] Error: ${POLL_RESULT#ERROR:}" >&2
        [[ -n "${COMFYUI_PID}" ]] && kill "${COMFYUI_PID}" 2>/dev/null || true
        rm -rf "${WORK_DIR}"
        exit 1
    fi

    # Show progress
    PROGRESS=$(curl -sf "${COMFYUI_URL}/prompt" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    qi = data.get('exec_info', {}).get('queue_remaining', '?')
    print(f'queue: {qi}', end='')
except: pass
" 2>/dev/null || echo "...")
    echo -ne "\r[video-ai] ${PROGRESS}  " >&2

    sleep 2
done

# ── Find output files ────────────────────────────────────────────────
mkdir -p "${OUTPUT_DIR}"

# ComfyUI SaveImage outputs PNG sequence to COMFYUI_OUTPUT
# Find PNGs newer than the workflow submission
FIRST_PNG=$(find "${COMFYUI_OUTPUT}" -name "*.png" -newer "${WORKFLOW_RESOLVED}" 2>/dev/null | sort | head -1)

if [[ -z "${FIRST_PNG}" ]]; then
    # Fallback: any PNG in the output dir
    FIRST_PNG=$(find "${COMFYUI_OUTPUT}" -name "*.png" 2>/dev/null | sort | head -1)
fi

if [[ -z "${FIRST_PNG}" ]]; then
    echo "Error: No output files found after generation" >&2
    [[ -n "${COMFYUI_PID}" ]] && kill "${COMFYUI_PID}" 2>/dev/null || true
    exit 1
fi

PNG_COUNT=$(find "$(dirname "${FIRST_PNG}")" -name "*.png" 2>/dev/null | wc -l)
echo "[video-ai] Found ${PNG_COUNT} frames" >&2

# Build ffmpeg glob input pattern from the directory
PNG_DIR=$(dirname "${FIRST_PNG}")

# ── Encode to MP4 ────────────────────────────────────────────────────
OUTPUT_MP4="${OUTPUT_DIR}/${MODEL}_${TIMESTAMP}_${SLUG}.mp4"

echo "[video-ai] Encoding to MP4..." >&2

# Select encoder: software (VAAPI doesn't accept PNG input well)
if [[ "${COMPAT}" == "true" ]]; then
    ENCODER_ARGS=(-c:v libx264 -preset medium -crf 18)
else
    ENCODER_ARGS=(-c:v libx265 -preset medium -crf 18)
fi

# Encode PNG sequence to MP4
ffmpeg -y -framerate 24 -pattern_type glob -i "${PNG_DIR}/*.png" \
    -pix_fmt yuv420p \
    "${ENCODER_ARGS[@]}" \
    -f mp4 "${OUTPUT_MP4}" 2>/dev/null

# ── Cleanup ──────────────────────────────────────────────────────────
rm -rf "${WORK_DIR}"
rm -rf "${COMFYUI_OUTPUT:?}"/*  # Clear ComfyUI output PNGs
[[ -n "${COMFYUI_PID}" ]] && kill "${COMFYUI_PID}" 2>/dev/null || true

echo "[video-ai] Output: ${OUTPUT_MP4}" >&2
echo "${OUTPUT_MP4}"
