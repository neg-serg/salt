#!/bin/bash
# shellcheck disable=SC2153  # Variables are set by the sourcing script
# Shared ComfyUI lifecycle functions for video-ai-generate.sh and video-ai-generate-image.sh.
# Source this file after setting: COMFYUI_URL, COMFYUI_DIR, COMFYUI_PORT, VENV_PYTHON, COMFYUI_OUTPUT.

# ── Guard: required env vars ────────────────────────────────────────
for _var in COMFYUI_URL COMFYUI_DIR COMFYUI_PORT VENV_PYTHON COMFYUI_OUTPUT; do
    if [[ -z "${!_var:-}" ]]; then
        echo "lib-comfyui.sh: required variable ${_var} is not set" >&2
        exit 1
    fi
done
unset _var

# ── comfyui_start: start ComfyUI if not running, wait for health ───
# Usage: comfyui_start "log-prefix" [extra_dirs...]
comfyui_start() {
    local log_prefix="$1"; shift
    mkdir -p "${COMFYUI_OUTPUT}" "$@"
    COMFYUI_PID=""
    if ! curl -sf "${COMFYUI_URL}/system_stats" >/dev/null 2>&1; then
        echo "[${log_prefix}] Starting ComfyUI on port ${COMFYUI_PORT}..." >&2
        cd "${COMFYUI_DIR}" || exit 1
        "${VENV_PYTHON}" main.py \
            --listen 127.0.0.1 \
            --port "${COMFYUI_PORT}" \
            --disable-auto-launch \
            --output-directory "${COMFYUI_OUTPUT}" \
            >/dev/null 2>&1 &
        COMFYUI_PID=$!

        echo -n "[${log_prefix}] Waiting for ComfyUI..." >&2
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
}

# ── comfyui_submit: submit workflow JSON, set PROMPT_ID ─────────────
# Usage: comfyui_submit "log-prefix" workflow_file
comfyui_submit() {
    local log_prefix="$1"
    local workflow_file="$2"

    RESPONSE=$(curl -sf -X POST "${COMFYUI_URL}/prompt" \
        -H "Content-Type: application/json" \
        -d @"${workflow_file}")

    PROMPT_ID=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['prompt_id'])" 2>/dev/null || true)

    if [[ -z "${PROMPT_ID}" ]]; then
        echo "Error: Failed to submit workflow to ComfyUI" >&2
        echo "Response: ${RESPONSE}" >&2
        if [[ -n "${COMFYUI_PID:-}" ]]; then kill "${COMFYUI_PID}" 2>/dev/null || true; fi
        exit 1
    fi
}

# ── comfyui_poll: poll for completion, exit 1 on error ──────────────
# Usage: comfyui_poll "log-prefix" [--progress]
comfyui_poll() {
    local log_prefix="$1"; shift
    local show_progress=false
    [[ "${1:-}" == "--progress" ]] && show_progress=true

    while true; do
        HISTORY=$(curl -sf "${COMFYUI_URL}/history/${PROMPT_ID}" 2>/dev/null || echo "{}")

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
            if [[ "${show_progress}" == "true" ]]; then
                echo -e "\n[${log_prefix}] Generation complete!" >&2
            fi
            break
        elif [[ "${POLL_RESULT}" == ERROR:* ]]; then
            echo "[${log_prefix}] Error: ${POLL_RESULT#ERROR:}" >&2
            rm -rf "${WORK_DIR:-}"
            if [[ -n "${COMFYUI_PID:-}" ]]; then kill "${COMFYUI_PID}" 2>/dev/null || true; fi
            exit 1
        fi

        if [[ "${show_progress}" == "true" ]]; then
            PROGRESS=$(curl -sf "${COMFYUI_URL}/prompt" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    qi = data.get('exec_info', {}).get('queue_remaining', '?')
    print(f'queue: {qi}', end='')
except: pass
" 2>/dev/null || echo "...")
            echo -ne "\r[${log_prefix}] ${PROGRESS}  " >&2
        fi

        sleep 2
    done
}
