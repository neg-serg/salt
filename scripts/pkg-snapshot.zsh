#!/usr/bin/env zsh
# pkg-snapshot.zsh — Capture current system packages into states/data/packages.yaml
#
# Reads pacman -Qqe (explicitly installed packages), excludes packages already
# managed by domain-specific Salt states, auto-categorizes the remainder, and
# writes a YAML file consumable by packages.sls.
#
# Usage:
#   ./scripts/pkg-snapshot.zsh              # Generate packages.yaml
#   ./scripts/pkg-snapshot.zsh --reduce     # Also show reduction candidates
#   ./scripts/pkg-snapshot.zsh --dry-run    # Print to stdout, don't write file
#   ./scripts/pkg-snapshot.zsh --help

set -euo pipefail

# --- Config ---
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
STATES_DIR="${PROJECT_DIR}/states"
DATA_DIR="${STATES_DIR}/data"
OUTPUT_FILE="${DATA_DIR}/packages.yaml"

# --- Flags ---
typeset -i flag_reduce=0
typeset -i flag_dry_run=0

usage() {
    cat <<'EOF'
Usage: pkg-snapshot.zsh [OPTIONS]

Capture current system packages into states/data/packages.yaml.

Options:
  --reduce     After generating YAML, show packages that could be removed
               from the explicit list (they are transitive deps of other
               explicit packages). Requires pactree (pacman-contrib).
  --dry-run    Print YAML to stdout instead of writing to file.
  --help       Show this help.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reduce)  flag_reduce=1; shift ;;
        --dry-run) flag_dry_run=1; shift ;;
        --help)    usage ;;
        *)         echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Step 1: Collect packages managed by domain-specific Salt states ---
# We parse .sls files and data YAML files to find package names.
typeset -A managed  # associative array: pkg_name → owning_file

extract_sls_packages() {
    local sls_file="$1"
    local basename="${sls_file:t}"

    # Pattern 1: pacman_install('name', 'pkg1 pkg2 pkg3')
    rg -oN "pacman_install\('[^']*',\s*'([^']*)'" "$sls_file" 2>/dev/null | while IFS= read -r line; do
        local pkgs="${line##*\'}"
        pkgs="${line%\'*}"
        pkgs="${pkgs##*\'}"
        for pkg in ${(s: :)pkgs}; do
            managed[$pkg]="$basename"
        done
    done

    # Pattern 2: paru_install('name', 'pkg')
    rg -oN "paru_install\('[^']*',\s*'([^']*)'" "$sls_file" 2>/dev/null | while IFS= read -r line; do
        local pkg="${line##*\'}"
        pkg="${line%\'*}"
        pkg="${pkg##*\'}"
        managed[$pkg]="$basename"
    done

    # Pattern 3: inline for-loops with lists
    # e.g.: {% for pkg in ['pipewire-audio', 'wireplumber', ...] %}
    rg -oN "for pkg in \[([^\]]+)\]" "$sls_file" 2>/dev/null | while IFS= read -r line; do
        local list_part="${line#*\[}"
        list_part="${list_part%\]*}"
        # Extract quoted strings
        echo "$list_part" | rg -oN "'([^']+)'" | while IFS= read -r item; do
            local pkg="${item//\'/}"
            managed[$pkg]="$basename"
        done
    done

    # Pattern 4: manual pacman -S --noconfirm --needed pkg1 pkg2 ...
    rg -oN 'pacman -S --noconfirm --needed[^|&\n]*' "$sls_file" 2>/dev/null | while IFS= read -r line; do
        # Strip flags (--ask 4, etc.)
        local cleaned="${line#*--needed}"
        for token in ${(s: :)cleaned}; do
            # Skip flags
            [[ "$token" == --* ]] && continue
            [[ "$token" == [0-9]* ]] && continue
            [[ -z "$token" ]] && continue
            managed[$token]="$basename"
        done
    done
}

extract_yaml_packages() {
    local yaml_file="$1"
    local basename="${yaml_file:t}"

    # Extract values from pacman: and paru: top-level sections
    # These are simple key: value pairs where value is the package name
    local in_section=""
    while IFS= read -r line; do
        # Detect top-level section
        if [[ "$line" =~ '^(pacman|paru|paru_install):' ]]; then
            in_section="yes"
            continue
        fi
        # End section on next top-level key (no leading whitespace)
        if [[ -n "$in_section" && "$line" =~ '^[a-z]' && ! "$line" =~ '^\s' ]]; then
            in_section=""
            continue
        fi
        # In a pacman/paru section, extract the package name (value after colon)
        if [[ -n "$in_section" && "$line" =~ '^\s+[a-z]' ]]; then
            # key: value — we want the value (package name)
            local val="${line#*: }"
            val="${val## }"
            val="${val%% *}"  # take first word only
            # Skip URLs, comments, booleans
            [[ "$val" == http* ]] && continue
            [[ "$val" == \#* ]] && continue
            [[ "$val" == true || "$val" == false ]] && continue
            [[ -z "$val" ]] && continue
            managed[$val]="$basename"
        fi
    done < "$yaml_file"
}

echo "=== Extracting packages from Salt states ===" >&2

# Parse all .sls files
for sls_file in "${STATES_DIR}"/*.sls; do
    [[ -f "$sls_file" ]] || continue
    extract_sls_packages "$sls_file"
done

# Parse data YAML files known to contain package definitions
for yaml_file in "${DATA_DIR}/fonts.yaml" "${DATA_DIR}/installers_desktop.yaml"; do
    [[ -f "$yaml_file" ]] || continue
    extract_yaml_packages "$yaml_file"
done

echo "  Found ${#managed} packages managed by domain-specific states" >&2

# --- Step 2: Capture system state ---
echo "=== Capturing system package state ===" >&2

# All explicitly installed packages
typeset -a explicit_pkgs
explicit_pkgs=("${(@f)$(pacman -Qqe)}")
echo "  Explicitly installed: ${#explicit_pkgs}" >&2

# Foreign (AUR) packages
typeset -A aur_pkgs
for pkg in $(pacman -Qqm); do
    aur_pkgs[$pkg]=1
done
echo "  Foreign/AUR: ${#aur_pkgs}" >&2

# --- Step 3: Filter out managed packages ---
typeset -a unmanaged_official
typeset -a unmanaged_aur

for pkg in "${explicit_pkgs[@]}"; do
    # Skip if managed by a domain state
    if (( ${+managed[$pkg]} )); then
        continue
    fi

    if (( ${+aur_pkgs[$pkg]} )); then
        unmanaged_aur+=("$pkg")
    else
        unmanaged_official+=("$pkg")
    fi
done

echo "  After excluding domain-managed:" >&2
echo "    Official: ${#unmanaged_official}" >&2
echo "    AUR: ${#unmanaged_aur}" >&2

# --- Step 4: Auto-categorize official packages ---
# Strategy: use pacman groups + heuristic keyword matching

# Collect group memberships
typeset -A pkg_groups
pacman -Qg 2>/dev/null | while read -r grp pkg_name; do
    # Accumulate groups per package
    if (( ${+pkg_groups[$pkg_name]} )); then
        pkg_groups[$pkg_name]="${pkg_groups[$pkg_name]} ${grp}"
    else
        pkg_groups[$pkg_name]="$grp"
    fi
done

categorize_pkg() {
    local pkg="$1"
    local groups="${pkg_groups[$pkg]:-}"

    # Group-based categorization
    [[ "$groups" == *base-devel* ]] && { echo "base"; return; }
    [[ "$groups" == *base* ]] && { echo "base"; return; }
    [[ "$groups" == *xorg* ]] && { echo "desktop"; return; }

    # Keyword heuristics on package name
    case "$pkg" in
        linux-cachyos*|linux-firmware*|base|base-devel|mkinitcpio*|limine*)
            echo "base"; return ;;
        hypr*|wayland*|wl-*|wlr-*|xdg-*|rofi*|foot*|waybar*|dunst*|mako*|swaylock*|sway*)
            echo "desktop"; return ;;
        pipewire*|wireplumber*|alsa*|pulseaudio*|jack*|playerctl*)
            echo "audio"; return ;;
        python*|rustup*|rust|cargo*|gcc*|gdb*|cmake*|make|go|git|neovim*|vim*|clang*|llvm*|nodejs*|npm*|lua*|ruby*)
            echo "dev"; return ;;
        networkmanager*|openssh*|curl|wget|nmap*|wireguard*|openvpn*|bind*|dnsutils*|iproute2*|iptables*|nftables*|firewalld*)
            echo "network"; return ;;
        ttf-*|otf-*|font*|noto-*)
            echo "fonts"; return ;;
        steam*|gamescope*|mangohud*|gamemode*|vulkan*|lib32-vulkan*|wine*|proton*|dxvk*|lutris*|protontricks*)
            echo "gaming"; return ;;
        ffmpeg*|mpv*|imagemagick*|gstreamer*|gst-*|v4l*|obs*|vlc*)
            echo "media"; return ;;
        btrfs*|snapper*|lvm2*|mdadm*|parted*|gdisk*|dosfstools*|e2fsprogs*|ntfs*|htop*|btop*|rsync*|strace*|sysstat*|lsof*)
            echo "system"; return ;;
    esac

    # Fallback
    echo "other"
}

# Build category arrays
typeset -A categories
for cat_name in base desktop dev network audio media fonts gaming system other; do
    categories[$cat_name]=""
done

typeset cat_result
for pkg in "${unmanaged_official[@]}"; do
    cat_result="$(categorize_pkg "$pkg")"
    if [[ -n "${categories[$cat_result]}" ]]; then
        categories[$cat_result]="${categories[$cat_result]}\n${pkg}"
    else
        categories[$cat_result]="$pkg"
    fi
done

# --- Step 5: Generate YAML output ---
generate_yaml() {
    cat <<'HEADER'
# states/data/packages.yaml
# Categorized package declarations for Salt-managed installation.
# Official repo packages are installed via pacman; AUR packages via paru.
# Packages managed by domain-specific states (audio.sls, fonts.sls, steam.sls, etc.)
# are NOT listed here — see: ./scripts/pkg-snapshot.zsh for the extraction logic.
#
# Generated by: scripts/pkg-snapshot.zsh
HEADER
    printf '# Generated on: %s\n' "$(date -I)"
    echo ""

    # Domain-managed categories with notes
    typeset -A domain_notes
    domain_notes=(
        [audio]="audio.sls"
        [fonts]="fonts.sls"
        [gaming]="steam.sls"
    )

    for cat_name in base desktop dev network audio media fonts gaming system other; do
        echo "${cat_name}:"

        # Check if this is a domain-managed-only category
        if [[ -n "${domain_notes[$cat_name]:-}" && -z "${categories[$cat_name]:-}" ]]; then
            echo "  # NOTE: most ${cat_name} packages managed by ${domain_notes[$cat_name]} — not listed here"
        elif [[ -n "${categories[$cat_name]:-}" ]]; then
            # Add domain note if applicable
            if [[ -n "${domain_notes[$cat_name]:-}" ]]; then
                echo "  # NOTE: some ${cat_name} packages managed by ${domain_notes[$cat_name]}"
            fi
            # Sort and output packages
            echo -e "${categories[$cat_name]}" | sort -u | while IFS= read -r pkg; do
                [[ -n "$pkg" ]] && echo "  - ${pkg}"
            done
        else
            echo "  []"
        fi
        echo ""
    done

    # AUR section
    echo "aur:"
    if [[ ${#unmanaged_aur} -gt 0 ]]; then
        echo "  # NOTE: some AUR packages managed by domain states (desktop.sls, installers_desktop.sls, etc.)"
        printf '%s\n' "${unmanaged_aur[@]}" | sort -u | while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && echo "  - ${pkg}"
        done
    else
        echo "  []"
    fi
}

echo "=== Generating packages.yaml ===" >&2

yaml_content="$(generate_yaml)"

if (( flag_dry_run )); then
    echo "$yaml_content"
    echo "" >&2
    echo "=== Dry run — not writing to file ===" >&2
else
    echo "$yaml_content" > "$OUTPUT_FILE"
    echo "  Written to: ${OUTPUT_FILE}" >&2
fi

# Count totals
typeset -i total_official=0
typeset -i cnt=0
for cat_name in base desktop dev network audio media fonts gaming system other; do
    if [[ -n "${categories[$cat_name]:-}" ]]; then
        cnt=$(echo -e "${categories[$cat_name]}" | grep -c '[a-z]' || true)
        total_official=$((total_official + cnt))
    fi
done
echo "" >&2
echo "=== Summary ===" >&2
echo "  Official packages: ${total_official}" >&2
echo "  AUR packages: ${#unmanaged_aur}" >&2
echo "  Total in packages.yaml: $((total_official + ${#unmanaged_aur}))" >&2
echo "  Excluded (domain-managed): ${#managed}" >&2

# --- Step 6: Optional reduction pass ---
if (( flag_reduce )); then
    echo "" >&2
    echo "=== Reduction Candidates ===" >&2

    if ! command -v pactree &>/dev/null; then
        echo "ERROR: pactree not found. Install pacman-contrib:" >&2
        echo "  sudo pacman -S pacman-contrib" >&2
        exit 1
    fi

    echo "The following explicitly-installed packages are already transitive"
    echo "dependencies of other explicit packages and could be removed from"
    echo "the explicit list (they would still be installed as dependencies):"
    echo ""

    # Build set of all explicit packages for quick lookup
    typeset -A explicit_set
    for pkg in "${explicit_pkgs[@]}"; do
        explicit_set[$pkg]=1
    done

    typeset -i candidate_count=0

    for pkg in "${explicit_pkgs[@]}"; do
        # Get reverse deps (packages that depend on this one)
        typeset -a rev_deps
        rev_deps=("${(@f)$(pactree -r -d1 "$pkg" 2>/dev/null | tail -n +2)}" )

        # Check if any reverse dep is also explicitly installed
        typeset -a explicit_dependents
        explicit_dependents=()
        for rdep in "${rev_deps[@]}"; do
            # pactree output has leading whitespace and sometimes provides/version info
            rdep="${rdep## }"
            rdep="${rdep%%:*}"
            rdep="${rdep%% *}"
            [[ -z "$rdep" ]] && continue
            [[ "$rdep" == "$pkg" ]] && continue
            if (( ${+explicit_set[$rdep]} )); then
                explicit_dependents+=("$rdep")
            fi
        done

        if [[ ${#explicit_dependents} -gt 0 ]]; then
            printf "  %-30s (dependency of: %s)\n" "$pkg" "${(j:, :)explicit_dependents}"
            candidate_count=$((candidate_count + 1))
        fi
    done

    echo ""
    echo "Review each candidate before removing. Some packages may be"
    echo "intentionally explicit (e.g., you want a library even if its"
    echo "only current dependent is removed later)."
    echo ""
    echo "Total: ${candidate_count} candidates out of ${#explicit_pkgs} explicit packages"
fi
