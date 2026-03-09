#!/usr/bin/env zsh
# pkg-drift.zsh — Compare declared packages against actual system state
#
# Reports three categories:
#   UNMANAGED: installed explicitly but not declared in packages.yaml or any .sls file
#   MISSING:   declared in packages.yaml or .sls files but not installed
#   ORPHANS:   dependency-only packages with no remaining dependents
#
# Usage:
#   ./scripts/pkg-drift.zsh           # Full report
#   ./scripts/pkg-drift.zsh --quiet   # Exit code only (0=clean, 1=drift)
#   ./scripts/pkg-drift.zsh --help

set -euo pipefail

# --- Config ---
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
STATES_DIR="${PROJECT_DIR}/states"
DATA_DIR="${STATES_DIR}/data"
PACKAGES_YAML="${DATA_DIR}/packages.yaml"

# --- Flags ---
typeset -i flag_quiet=0

usage() {
    cat <<'EOF'
Usage: pkg-drift.zsh [OPTIONS]

Compare declared packages against actual system state.

Options:
  --quiet   Suppress output; exit 0 if no drift, 1 if drift detected.
  --help    Show this help.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quiet) flag_quiet=1; shift ;;
        --help)  usage ;;
        *)       echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Step 1: Collect declared packages ---
typeset -A declared  # pkg_name → source

# Parse packages.yaml
if [[ -f "$PACKAGES_YAML" ]]; then
    while IFS= read -r line; do
        # Match lines like "  - package-name"
        if [[ "$line" =~ '^\s+-\s+(.+)$' ]]; then
            local pkg="${match[1]}"
            pkg="${pkg## }"
            pkg="${pkg%% }"
            [[ -n "$pkg" ]] && declared[$pkg]="packages.yaml"
        fi
    done < "$PACKAGES_YAML"
fi

# Parse .sls files for pacman_install/paru_install macro calls
for sls_file in "${STATES_DIR}"/*.sls; do
    [[ -f "$sls_file" ]] || continue
    local basename="${sls_file:t}"

    # pacman_install('name', 'pkg1 pkg2 pkg3')
    rg -oN "pacman_install\('[^']*',\s*'([^']*)'" "$sls_file" 2>/dev/null | while IFS= read -r line; do
        local pkgs="${line%\'*}"
        pkgs="${pkgs##*\'}"
        for pkg in ${(s: :)pkgs}; do
            declared[$pkg]="$basename"
        done
    done

    # paru_install('name', 'pkg')
    rg -oN "paru_install\('[^']*',\s*'([^']*)'" "$sls_file" 2>/dev/null | while IFS= read -r line; do
        local pkg="${line%\'*}"
        pkg="${pkg##*\'}"
        declared[$pkg]="$basename"
    done

    # inline for-loops: {% for pkg in ['pkg1', 'pkg2'] %}
    rg -oN "for pkg in \[([^\]]+)\]" "$sls_file" 2>/dev/null | while IFS= read -r line; do
        local list_part="${line#*\[}"
        list_part="${list_part%\]*}"
        echo "$list_part" | rg -oN "'([^']+)'" | while IFS= read -r item; do
            local pkg="${item//\'/}"
            declared[$pkg]="$basename"
        done
    done

    # manual pacman -S --noconfirm --needed pkg1 pkg2
    rg -oN 'pacman -S --noconfirm --needed[^|&\n]*' "$sls_file" 2>/dev/null | while IFS= read -r line; do
        local cleaned="${line#*--needed}"
        for token in ${(s: :)cleaned}; do
            [[ "$token" == --* ]] && continue
            [[ "$token" == [0-9]* ]] && continue
            [[ -z "$token" ]] && continue
            declared[$token]="$basename"
        done
    done
done

# Parse data YAML files with pacman/paru sections
for yaml_file in "${DATA_DIR}/fonts.yaml" "${DATA_DIR}/installers_desktop.yaml"; do
    [[ -f "$yaml_file" ]] || continue
    local basename="${yaml_file:t}"
    local in_section=""
    while IFS= read -r line; do
        if [[ "$line" =~ '^(pacman|paru|paru_install):' ]]; then
            in_section="yes"
            continue
        fi
        if [[ -n "$in_section" && "$line" =~ '^[a-z]' && ! "$line" =~ '^\s' ]]; then
            in_section=""
            continue
        fi
        if [[ -n "$in_section" && "$line" =~ '^\s+[a-z]' ]]; then
            local val="${line#*: }"
            val="${val## }"
            val="${val%% *}"
            [[ "$val" == http* ]] && continue
            [[ "$val" == \#* ]] && continue
            [[ "$val" == true || "$val" == false ]] && continue
            [[ -z "$val" ]] && continue
            declared[$val]="$basename"
        fi
    done < "$yaml_file"
done

# --- Step 2: Get actual system state ---
typeset -A actual_explicit
for pkg in $(pacman -Qqe); do
    actual_explicit[$pkg]=1
done

typeset -A actual_all
for pkg in $(pacman -Qq); do
    actual_all[$pkg]=1
done

# --- Step 3: Compare ---
typeset -a unmanaged_list
typeset -a missing_list
typeset -a orphan_list

# Unmanaged: explicitly installed but not declared
for pkg in ${(k)actual_explicit}; do
    if ! (( ${+declared[$pkg]} )); then
        unmanaged_list+=("$pkg")
    fi
done

# Missing: declared but not installed at all
for pkg in ${(k)declared}; do
    if ! (( ${+actual_all[$pkg]} )); then
        missing_list+=("$pkg")
    fi
done

# Orphans: dependency-only packages with no dependents
orphan_list=("${(@f)$(pacman -Qdtq 2>/dev/null)}" )
# Filter empty entries
orphan_list=("${(@)orphan_list:#}")

# --- Step 4: Report ---
typeset -i drift=0

if [[ ${#unmanaged_list} -gt 0 || ${#missing_list} -gt 0 || ${#orphan_list} -gt 0 ]]; then
    drift=1
fi

if (( flag_quiet )); then
    exit $drift
fi

echo "=== Package Drift Report ($(date -I)) ==="
echo ""

if [[ ${#unmanaged_list} -gt 0 ]]; then
    echo "UNMANAGED (installed but not declared):"
    printf '%s\n' "${(@o)unmanaged_list}" | while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && echo "  - $pkg"
    done
    echo ""
fi

if [[ ${#missing_list} -gt 0 ]]; then
    echo "MISSING (declared but not installed):"
    printf '%s\n' "${(@o)missing_list}" | while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && echo "  - $pkg"
    done
    echo ""
fi

if [[ ${#orphan_list} -gt 0 ]]; then
    echo "ORPHANS (dependency-only, no dependents):"
    printf '%s\n' "${(@o)orphan_list}" | while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && echo "  - $pkg"
    done
    echo ""
fi

echo "Summary: ${#unmanaged_list} unmanaged, ${#missing_list} missing, ${#orphan_list} orphans"

exit $drift
