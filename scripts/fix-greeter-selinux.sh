#!/bin/bash
# Fix SELinux denials for greetd greeter (xdm_t domain)
# Allows mmap on fontconfig cache (fast fonts) and cache_home_t (wallpaper)
# Run as root: sudo bash scripts/fix-greeter-selinux.sh
set -euo pipefail

if semodule -l | grep -q '^greetd-cache'; then
    echo "greetd-cache SELinux module already installed"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/greetd-cache.te" << 'POLICY'
module greetd-cache 1.0;
require {
    type xdm_t;
    type cache_home_t;
    type user_fonts_cache_t;
    class file { read open getattr map };
}
allow xdm_t user_fonts_cache_t:file map;
allow xdm_t cache_home_t:file { read open getattr map };
POLICY

echo "Compiling SELinux module..."
checkmodule -M -m -o "$TMP/greetd-cache.mod" "$TMP/greetd-cache.te"
semodule_package -o "$TMP/greetd-cache.pp" -m "$TMP/greetd-cache.mod"

echo "Installing SELinux module..."
semodule -i "$TMP/greetd-cache.pp"

echo "Done. greetd-cache SELinux module installed."
echo "Reboot to verify greeter shows wallpaper and starts faster."
