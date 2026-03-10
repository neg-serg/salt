#!/usr/bin/env bash
# Shared functions for speech engine setup scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure ROCm binaries are on PATH
if [[ -d /opt/rocm/bin ]] && ! echo "$PATH" | grep -q /opt/rocm/bin; then
    export PATH="/opt/rocm/bin:$PATH"
fi
VOICES_DIR="$SCRIPT_DIR/voices"
CONFIG_DIR="$SCRIPT_DIR/config"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

warn() {
    echo "[$(date '+%H:%M:%S')] WARNING: $*" >&2
}

error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2
    exit 1
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        error "$1 is required but not found. $2"
    fi
}

download_model() {
    local url="$1"
    local dest="$2"
    if [[ -f "$dest" ]]; then
        log "Model already exists: $dest"
        return 0
    fi
    log "Downloading $(basename "$dest")..."
    mkdir -p "$(dirname "$dest")"
    curl -L --progress-bar -o "$dest" "$url"
    log "Downloaded: $dest ($(du -h "$dest" | cut -f1))"
}

setup_venv() {
    local venv_dir="$1"
    if [[ -d "$venv_dir" ]]; then
        log "Venv already exists: $venv_dir"
    else
        log "Creating venv: $venv_dir"
        python3 -m venv "$venv_dir"
    fi
    source "$venv_dir/bin/activate"
    log "Activated venv: $venv_dir"
}
