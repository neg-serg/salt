#!/usr/bin/env bash
# Diagnostic script for Xalia X11/XWayland availability
# Checks both the host environment and the distrobox steam container

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()      { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()    { printf "${RED}[FAIL]${NC}  %s\n" "$*"; }
section() { printf "\n${CYAN}=== %s ===${NC}\n\n" "$*"; }

ISSUES=0
bump() { ((ISSUES++)) || true; }

CONTAINER="steam"

section "Host: XWayland process"
if pgrep -x Xwayland >/dev/null 2>&1; then
    pid=$(pgrep -x Xwayland)
    ok "Xwayland running (PID $pid)"
    ps -p "$pid" -o args= 2>/dev/null | sed 's/^/     /'
else
    fail "Xwayland is NOT running"; bump
    echo "     Hyprland starts it lazily on first X11 client."
    echo "     Try: xeyes & sleep 1 && kill %1"
fi

section "Host: Environment variables"
if [[ -n "${DISPLAY:-}" ]]; then
    ok "DISPLAY=$DISPLAY"
else
    fail "DISPLAY is not set"; bump
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    ok "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
else
    warn "WAYLAND_DISPLAY is not set"
fi

if [[ "${SDL_VIDEODRIVER:-}" == "x11" ]]; then
    ok "SDL_VIDEODRIVER=x11 (forces XWayland)"
elif [[ -n "${SDL_VIDEODRIVER:-}" ]]; then
    warn "SDL_VIDEODRIVER=${SDL_VIDEODRIVER} (Xalia needs x11)"
else
    warn "SDL_VIDEODRIVER is not set (Xalia needs x11)"
fi

section "Host: Hyprland xwayland config"
if command -v hyprctl >/dev/null 2>&1; then
    xwl_enabled=$(hyprctl getoption xwayland:enabled 2>/dev/null | grep -oP 'int:\s*\K\d+' || echo "?")
    if [[ "$xwl_enabled" == "1" ]]; then
        ok "xwayland:enabled = 1"
    elif [[ "$xwl_enabled" == "0" ]]; then
        fail "xwayland:enabled = 0 — XWayland is disabled!"; bump
    else
        warn "Could not read xwayland:enabled (got: $xwl_enabled)"
    fi
else
    warn "hyprctl not found"
fi

section "Host: X11 socket"
found_socket=0
for sock in /tmp/.X11-unix/X*; do
    [[ -e "$sock" ]] || continue
    found_socket=1
    ok "X11 socket exists: $sock"
done
if [[ "$found_socket" -eq 0 ]]; then
    fail "No X11 sockets in /tmp/.X11-unix/"; bump
fi

section "Host: xhost access control"
if command -v xhost >/dev/null 2>&1; then
    xhost_out=$(xhost 2>&1) || true
    if echo "$xhost_out" | grep -qi "access control disabled"; then
        ok "X11 access control disabled (all clients allowed)"
    elif echo "$xhost_out" | grep -q "SI:localuser:$(whoami)"; then
        ok "xhost allows localuser:$(whoami)"
    else
        warn "xhost may block container access"
        echo "     Current policy:"
        echo "$xhost_out" | sed 's/^/       /'
        echo "     Fix: xhost +si:localuser:$USER"
    fi
else
    warn "xhost not found — cannot check X11 access control"
fi

section "Host: D-Bus/systemd user environment"
dbus_display=$(systemctl --user show-environment 2>/dev/null | grep '^DISPLAY=' | cut -d= -f2- || true)
if [[ -n "$dbus_display" ]]; then
    ok "DISPLAY in systemd env: $dbus_display"
else
    warn "DISPLAY not in systemd user env"
fi

dbus_sdl=$(systemctl --user show-environment 2>/dev/null | grep '^SDL_VIDEODRIVER=' | cut -d= -f2- || true)
if [[ -n "$dbus_sdl" ]]; then
    ok "SDL_VIDEODRIVER in systemd env: $dbus_sdl"
else
    warn "SDL_VIDEODRIVER not in systemd user env"
fi

section "Host: X11 connection test"
if command -v xdpyinfo >/dev/null 2>&1; then
    if xdpyinfo >/dev/null 2>&1; then
        ok "xdpyinfo connected successfully"
    else
        fail "xdpyinfo cannot connect to X11"; bump
    fi
elif command -v xset >/dev/null 2>&1; then
    if xset q >/dev/null 2>&1; then
        ok "xset connected successfully"
    else
        fail "xset cannot connect to X11"; bump
    fi
else
    warn "No X11 test tools (xdpyinfo/xset) available"
fi

section "Host: AT-SPI2 accessibility"
if pgrep -f at-spi2-registryd >/dev/null 2>&1 || pgrep -f at-spi-bus-launcher >/dev/null 2>&1; then
    ok "AT-SPI2 daemon is running"
else
    warn "AT-SPI2 daemon not detected"
fi

# ──────────────────────────────────────────────
# Distrobox container checks
# ──────────────────────────────────────────────

section "Distrobox: Container '${CONTAINER}'"
if ! command -v distrobox >/dev/null 2>&1; then
    warn "distrobox not found — skipping container checks"
elif ! podman container exists "$CONTAINER" 2>/dev/null; then
    warn "Container '$CONTAINER' does not exist — skipping"
else
    # Is the container running?
    state=$(podman inspect --format '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo "unknown")
    if [[ "$state" == "running" ]]; then
        ok "Container is running"
    else
        warn "Container state: $state (must be running for full checks)"
        echo "     Start with: distrobox enter $CONTAINER -- true"
    fi

    if [[ "$state" == "running" ]]; then
        section "Distrobox: Environment inside '${CONTAINER}'"

        # DISPLAY
        ctr_display=$(distrobox enter "$CONTAINER" -- printenv DISPLAY 2>/dev/null || true)
        if [[ -n "$ctr_display" ]]; then
            ok "DISPLAY=$ctr_display (inside container)"
        else
            fail "DISPLAY not set inside container"; bump
            echo "     distrobox should forward this automatically"
        fi

        # WAYLAND_DISPLAY
        ctr_wayland=$(distrobox enter "$CONTAINER" -- printenv WAYLAND_DISPLAY 2>/dev/null || true)
        if [[ -n "$ctr_wayland" ]]; then
            ok "WAYLAND_DISPLAY=$ctr_wayland (inside container)"
        else
            warn "WAYLAND_DISPLAY not set inside container"
        fi

        # SDL_VIDEODRIVER
        ctr_sdl=$(distrobox enter "$CONTAINER" -- printenv SDL_VIDEODRIVER 2>/dev/null || true)
        if [[ "$ctr_sdl" == "x11" ]]; then
            ok "SDL_VIDEODRIVER=x11 (inside container)"
        elif [[ -n "$ctr_sdl" ]]; then
            warn "SDL_VIDEODRIVER=$ctr_sdl inside container (Xalia needs x11)"
        else
            fail "SDL_VIDEODRIVER not set inside container"; bump
            echo "     Xalia's SDL will try Wayland first and fail."
            echo "     Fix: add to steam.ini:"
            echo "       additional_flags=\"... --env SDL_VIDEODRIVER=x11\""
        fi

        section "Distrobox: X11 socket visibility inside '${CONTAINER}'"
        ctr_sockets=$(distrobox enter "$CONTAINER" -- ls /tmp/.X11-unix/ 2>/dev/null || true)
        if [[ -n "$ctr_sockets" ]]; then
            ok "X11 sockets visible: $ctr_sockets"
        else
            fail "No X11 sockets visible inside container"; bump
        fi

        section "Distrobox: X11 connection from inside '${CONTAINER}'"
        if distrobox enter "$CONTAINER" -- bash -c 'command -v xdpyinfo' >/dev/null 2>&1; then
            if distrobox enter "$CONTAINER" -- xdpyinfo >/dev/null 2>&1; then
                ok "xdpyinfo works inside container"
            else
                fail "xdpyinfo fails inside container"; bump
                echo "     X11 connection broken. Check xhost and socket mounts."
            fi
        elif distrobox enter "$CONTAINER" -- bash -c 'command -v xset' >/dev/null 2>&1; then
            if distrobox enter "$CONTAINER" -- xset q >/dev/null 2>&1; then
                ok "xset works inside container"
            else
                fail "xset fails inside container"; bump
            fi
        else
            warn "No X11 tools in container — install xorg-xdpyinfo"
            echo "     distrobox enter $CONTAINER -- sudo pacman -S xorg-xdpyinfo"
        fi

        section "Distrobox: Xalia-relevant libraries inside '${CONTAINER}'"
        # Proton bundles its own Xalia, but check host SDL availability
        if distrobox enter "$CONTAINER" -- bash -c 'ldconfig -p 2>/dev/null | grep -q libSDL' 2>/dev/null; then
            ctr_sdl_lib=$(distrobox enter "$CONTAINER" -- bash -c 'ldconfig -p 2>/dev/null | grep "libSDL[23]" | head -3' 2>/dev/null || true)
            ok "SDL libraries found inside container:"
            echo "$ctr_sdl_lib" | sed 's/^/       /'
        else
            warn "No SDL libraries found via ldconfig inside container"
            echo "     Proton bundles its own, but native apps may fail"
        fi
    fi
fi

# ──────────────────────────────────────────────
# Proton-specific notes
# ──────────────────────────────────────────────

section "Proton: Xalia configuration"
echo "  Xalia is bundled with Proton Experimental (enabled by default since May 2025)."
echo "  It runs inside Wine/Proton — uses Win32 APIs, not AT-SPI2."
echo "  Its SDL overlay still needs X11/XWayland access from the container."
echo
echo "  To disable Xalia per-game (if it causes issues):"
echo "    Steam launch options: PROTON_ENABLE_XALIA=0 %command%"
echo
echo "  To force XWayland for Proton games:"
echo "    Steam launch options: SDL_VIDEODRIVER=x11 %command%"

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────

section "Summary"
if [[ "$ISSUES" -eq 0 ]]; then
    ok "All checks passed — environment looks ready for Xalia"
else
    fail "$ISSUES issue(s) found — see above for details"
fi
