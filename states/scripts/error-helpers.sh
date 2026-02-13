#!/bin/bash
# Shared error handling helpers for Salt cmd.run blocks
# Source this file at the start of multi-line cmd.run scripts for consistent error handling
# Usage: source /build/salt/error-helpers.sh

# Print timestamped status message
step() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$*"
}

# Print success message
success() {
    printf "[  ✓  ] %s\n" "$*"
}

# Print warning message
warn() {
    printf "[WARN ] %s\n" "$*" >&2
}

# Print error and exit with optional code
error_exit() {
    local msg="$1"
    local code="${2:-1}"
    printf "[ERROR] %s (exit code: %d)\n" "$msg" "$code" >&2
    exit "$code"
}

# Run command with error context
run_step() {
    local description="$1"
    shift
    step "$description"
    "$@" || error_exit "Failed: $description" "$?"
}

# Assert file/directory exists
assert_exists() {
    local path="$1"
    local type="${2:-file}"
    if [ ! -e "$path" ]; then
        error_exit "$type not found: $path" 1
    fi
}

# Guard: skip if path already exists
skip_if_exists() {
    local path="$1"
    local msg="${2:-Already exists}"
    if [ -e "$path" ]; then
        warn "$msg: $path"
        return 0
    fi
    return 1
}
