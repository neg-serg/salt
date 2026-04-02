# lib-utils.zsh — shared zsh utilities for scripts in ~/.local/bin/
# Source this at the top of scripts: source ~/.local/lib/lib-utils.zsh
# Works without .zshrc (no fpath, no compinit, explicit zmodload)

zmodload zsh/datetime 2>/dev/null  # for $EPOCHSECONDS

# --- Logging ---

_lib_utils_prog="${0:t}"

log_info()  { printf '%s [INFO]  %s: %s\n' "$(date '+%H:%M:%S')" "$_lib_utils_prog" "$*" >&2; }
log_warn()  { printf '%s [WARN]  %s: %s\n' "$(date '+%H:%M:%S')" "$_lib_utils_prog" "$*" >&2; }
log_error() { printf '%s [ERROR] %s: %s\n' "$(date '+%H:%M:%S')" "$_lib_utils_prog" "$*" >&2; }

# --- Error trapping ---

_lib_utils_cleanup() {
    local exit_code=$?
    if (( exit_code != 0 )); then
        log_error "exited with code $exit_code"
    fi
}
trap '_lib_utils_cleanup' EXIT

# --- Dependency checking ---

require_cmd() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "required command not found: $cmd"
            return 1
        fi
    done
}

# --- Retry with exponential backoff ---

retry() {
    local max_attempts=$1
    shift
    local attempt=1
    local delay=1

    while (( attempt <= max_attempts )); do
        if "$@"; then
            return 0
        fi
        if (( attempt == max_attempts )); then
            log_error "command failed after $max_attempts attempts: $*"
            return 1
        fi
        log_warn "attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
        sleep "$delay"
        (( delay *= 2 ))
        (( attempt++ ))
    done
}
