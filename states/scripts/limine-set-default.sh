#!/bin/bash
# Set the default boot entry in /boot/limine.conf.
# Usage: limine-set-default [ENTRY_NUMBER]
#   Without arguments: shows entries interactively.
#   With argument:     sets default directly.
set -euo pipefail

LIMINE="/boot/limine.conf"

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo limine-set-default [N]" >&2
    exit 1
fi

if [[ ! -f "$LIMINE" ]]; then
    echo "ERROR: $LIMINE not found" >&2
    exit 1
fi

# List top-level entries (lines starting with / but not //)
mapfile -t ENTRIES < <(rg '^/[^/]' "$LIMINE" | sed 's|^/||')
CURRENT=$(rg '^default_entry:' "$LIMINE" | head -1 | awk '{print $2}')

show_entries() {
    echo "Boot entries in $LIMINE:"
    for i in "${!ENTRIES[@]}"; do
        n=$((i + 1))
        marker="  "
        [[ "$n" == "$CURRENT" ]] && marker="» "
        echo "  ${marker}${n}  ${ENTRIES[$i]}"
    done
    echo ""
    echo "Current default: ${CURRENT}"
}

set_default() {
    local n="$1"
    if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n < 1 || n > ${#ENTRIES[@]} )); then
        echo "ERROR: Invalid entry number: $n (must be 1-${#ENTRIES[@]})" >&2
        exit 1
    fi
    sed -i "s/^default_entry: .*/default_entry: ${n}/" "$LIMINE"
    echo "Default set to ${n}: ${ENTRIES[$((n - 1))]}"
}

if [[ $# -ge 1 ]]; then
    set_default "$1"
else
    show_entries
    echo ""
    read -rp "Set default entry [1-${#ENTRIES[@]}]: " choice || true
    [[ -z "$choice" ]] && exit 0
    set_default "$choice"
fi
