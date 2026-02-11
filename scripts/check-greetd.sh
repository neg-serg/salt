#!/bin/bash
# Preflight check for greetd + quickshell greeter setup

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

pass=0
fail=0
warn=0

ok()   { echo -e "  ${GREEN}✓${NC} $1"; ((pass++)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ((fail++)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; ((warn++)); }

section() { echo -e "\n${BOLD}── $1 ──${NC}"; }

# --- RPM packages ---
section "RPM Packages"

for pkg in greetd quickshell; do
    if rpm -q "$pkg" &>/dev/null; then
        ok "$pkg $(rpm -q --qf '%{VERSION}' "$pkg") installed"
    else
        fail "$pkg not installed"
    fi
done

# --- Binaries ---
section "Binaries"

for bin in greetd agreety qs starthyprland Hyprland; do
    path=$(command -v "$bin" 2>/dev/null)
    if [ -n "$path" ]; then
        ok "$bin → $path"
    else
        fail "$bin not found in PATH"
    fi
done

# --- Config files ---
section "Config Files (/etc/greetd/)"

for f in config.toml hyprland-greeter.conf session-wrapper; do
    fp="/etc/greetd/$f"
    if [ -f "$fp" ]; then
        ok "$fp exists"
    else
        fail "$fp missing"
    fi
done

if [ -f /etc/greetd/session-wrapper ]; then
    if [ -x /etc/greetd/session-wrapper ]; then
        ok "session-wrapper is executable"
    else
        fail "session-wrapper is NOT executable"
    fi
fi

# --- Quickshell greeter QML ---
section "Quickshell Greeter"

greeter_dir="$HOME/.config/quickshell/greeter"
if [ -d "$greeter_dir" ]; then
    ok "$greeter_dir/ exists"
else
    fail "$greeter_dir/ missing (run: chezmoi apply ~/.config/quickshell/greeter/)"
fi

if [ -f "$greeter_dir/greeter.qml" ]; then
    ok "greeter.qml present"
else
    fail "greeter.qml missing"
fi

# --- PAM configs ---
section "PAM Configuration"

for f in greetd greetd-greeter; do
    if [ -f "/etc/pam.d/$f" ]; then
        ok "/etc/pam.d/$f exists"
    else
        fail "/etc/pam.d/$f missing"
    fi
done

# --- System user ---
section "System User"

if getent passwd greetd &>/dev/null; then
    ok "greetd user exists"
else
    fail "greetd user missing"
fi

if [ -d /var/lib/greetd ]; then
    ok "/var/lib/greetd/ exists"
else
    fail "/var/lib/greetd/ missing"
fi

# --- Systemd services ---
section "Systemd Services"

greetd_enabled=$(systemctl is-enabled greetd 2>/dev/null)
if [ "$greetd_enabled" = "enabled" ]; then
    ok "greetd.service enabled"
else
    fail "greetd.service is '$greetd_enabled' (expected: enabled)"
fi

sddm_enabled=$(systemctl is-enabled sddm 2>/dev/null)
if [ "$sddm_enabled" = "disabled" ] || [ "$sddm_enabled" = "not-found" ]; then
    ok "sddm.service disabled/absent"
else
    warn "sddm.service is '$sddm_enabled' — may conflict with greetd"
fi

# --- SELinux ---
section "SELinux"

if command -v semodule &>/dev/null; then
    if semodule -l 2>/dev/null | grep -q '^greetd'; then
        ok "greetd SELinux module loaded"
    else
        warn "greetd SELinux module not loaded (may cause denials)"
    fi
else
    warn "semodule not available, skipping SELinux check"
fi

# --- Summary ---
echo -e "\n${BOLD}── Summary ──${NC}"
echo -e "  ${GREEN}$pass passed${NC}  ${RED}$fail failed${NC}  ${YELLOW}$warn warnings${NC}"

if [ "$fail" -gt 0 ]; then
    echo -e "\n${RED}Fix the failures above before rebooting.${NC}"
    exit 1
else
    echo -e "\n${GREEN}All good — safe to reboot into greetd.${NC}"
    echo -e "  Rollback: Ctrl+Alt+F2 → login → sudo systemctl disable greetd && sudo systemctl enable sddm"
    exit 0
fi
