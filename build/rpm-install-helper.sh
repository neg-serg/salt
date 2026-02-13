#!/bin/bash
# Helper for install_rpms.sls: checks and installs custom RPMs
# Usage: rpm-install-helper.sh [check|install]
#   check   — exit 0 if all RPMs already installed, 1 if any missing
#   install — install missing RPMs via rpm-ostree
set -euo pipefail

RPM_DIR=/var/mnt/one/pkg/cache/rpms

# Discover RPMs, excluding debuginfo/debugsource
shopt -s nullglob
all_rpms=("$RPM_DIR"/*.rpm)
rpm_files=()
for f in "${all_rpms[@]}"; do
    case "${f##*/}" in *-debuginfo-*|*-debugsource-*) continue;; esac
    rpm_files+=("$f")
done
[ ${#rpm_files[@]} -eq 0 ] && exit 0

# Get package name.arch from all RPM files
mapfile -t pkg_ids < <(rpm -qp --queryformat '%{NAME}.%{ARCH}\n' "${rpm_files[@]}" 2>/dev/null)

case "${1:-install}" in
check)
    # Exit 0 if all packages are installed (rpm -q succeeds for all)
    rpm -q --queryformat '' "${pkg_ids[@]}" 2>/dev/null
    ;;
install)
    # Build lookup set of installed + layered packages
    installed=$(rpm -qa --queryformat '%{NAME}.%{ARCH}\n' | sort -u)
    layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-local-packages"[]?')
    declare -A have
    while IFS= read -r id; do [[ -n "$id" ]] && have["$id"]=1; done <<< "$installed"
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        arch="${entry##*.}"
        name="${entry%%-[0-9]*}"
        [[ -n "$name" && -n "$arch" ]] && have["${name}.${arch}"]=1
    done <<< "$layered"
    # Compute diff: RPMs not yet installed
    to_install=()
    for i in "${!pkg_ids[@]}"; do
        [[ -z "${have[${pkg_ids[$i]}]+x}" ]] && to_install+=("${rpm_files[$i]}")
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        echo "Installing ${#to_install[@]} RPM(s): ${to_install[*]##*/}"
        rpm-ostree install "${to_install[@]}"
    fi
    ;;
esac
