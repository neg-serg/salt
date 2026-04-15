#!/usr/bin/env zsh
# hot-reload.sh — fast restart of user-scope services without Salt
#
# Bypasses Salt render → Jinja → Quadlet → daemon-reload chain.
# Directly restarts the systemd user service and waits for health.
#
# Usage:
#   scripts/hot-reload.sh                    # list all reloadable services
#   scripts/hot-reload.sh nanoclaw           # restart NanoClaw (native Node.js)
#   scripts/hot-reload.sh telethon-bridge    # restart Telethon bridge (Quadlet)
#   scripts/hot-reload.sh opencode-telegram  # restart OpenCode Telegram bot (Quadlet)
#   scripts/hot-reload.sh telecode           # restart Telecode agent (Quadlet)
#   scripts/hot-reload.sh all                # restart all running services
#
# Environment:
#   HOT_RELOAD_TIMEOUT  Health check timeout in seconds (default: 30)

set -euo pipefail

TIMEOUT="${HOT_RELOAD_TIMEOUT:-30}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$RUNTIME_DIR"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${RUNTIME_DIR}/bus"

# ── Service registry ─────────────────────────────────────────────────
# Each entry: name | unit | health_cmd | type
# type: native (direct systemd unit) or quadlet (Podman Quadlet container)

declare -A SVC_UNIT SVC_HEALTH SVC_TYPE

SVC_UNIT[nanoclaw]='nanoclaw.service'
SVC_HEALTH[nanoclaw]='curl -sf http://127.0.0.1:8318/health >/dev/null 2>&1 || pgrep -f "node.*nanoclaw" >/dev/null'
SVC_TYPE[nanoclaw]='native'

SVC_UNIT[telethon-bridge]='telethon-bridge.service'
SVC_HEALTH[telethon-bridge]='pgrep -f telethon-bridge >/dev/null'
SVC_TYPE[telethon-bridge]='quadlet'

SVC_UNIT[opencode-telegram]='opencode-telegram-bot.service'
SVC_HEALTH[opencode-telegram]='pgrep -f opencode-telegram >/dev/null'
SVC_TYPE[opencode-telegram]='quadlet'

SVC_UNIT[telecode]='telecode.service'
SVC_HEALTH[telecode]='pgrep -f telecode >/dev/null'
SVC_TYPE[telecode]='quadlet'

SVC_UNIT[opencode-serve]='opencode-serve.service'
SVC_HEALTH[opencode-serve]='curl -sf http://127.0.0.1:4096/ >/dev/null 2>&1'
SVC_TYPE[opencode-serve]='quadlet'

# ── Helpers ──────────────────────────────────────────────────────────

list_services() {
    print -l "${(@k)SVC_UNIT}" | sort
}

is_active() {
    local unit="$1"
    systemctl --user is-active "$unit" &>/dev/null
}

wait_health() {
    local name="$1" health_cmd="$2"
    local elapsed=0
    while (( elapsed < TIMEOUT )); do
        if eval "$health_cmd" 2>/dev/null; then
            return 0
        fi
        sleep 1
        (( elapsed++ ))
    done
    return 1
}

reload_service() {
    local name="$1"
    local unit="${SVC_UNIT[$name]}"
    local health="${SVC_HEALTH[$name]}"
    local type="${SVC_TYPE[$name]}"

    if ! is_active "$unit"; then
        print -P "%F{yellow}⚠ %B${name}%b is not running — starting instead%f"
        systemctl --user start "$unit"
    else
        print -P "%F{cyan}→%f Restarting %B${name}%b (${type})..."
        systemctl --user restart "$unit"
    fi

    # Wait for health
    print -P "  Waiting for health (up to ${TIMEOUT}s)..."
    if wait_health "$name" "$health"; then
        print -P "%F{green}✓ %B${name}%b is healthy%f"
        return 0
    else
        print -P "%F{red}✗ %B${name}%b failed health check after ${TIMEOUT}s%f"
        print -P "  Unit status:"
        systemctl --user status "$unit" 2>&1 | head -15 | sed 's/^/    /'
        return 1
    fi
}

# ── Main ─────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    print -P "%BReloadable services:%b"
    print ""
    for svc in $(list_services); do
        local status
        if is_active "${SVC_UNIT[$svc]}"; then
            status="%F{green}running%f"
        else
            status="%F{red}stopped%f"
        fi
        printf "  %-25s %s  (%s)\n" "$svc" "$status" "${SVC_TYPE[$svc]}"
    done
    print ""
    print "Usage: $0 <service|all>"
    exit 0
fi

TARGET="$1"
FAILED=0

if [[ "$TARGET" == "all" ]]; then
    for svc in $(list_services); do
        if is_active "${SVC_UNIT[$svc]}"; then
            reload_service "$svc" || (( FAILED++ ))
        fi
    done
else
    if [[ -z "${SVC_UNIT[$TARGET]+_}" ]]; then
        print -P "%F{red}Unknown service: %B${TARGET}%b%f"
        print ""
        print "Available: $(list_services | tr '\n' ' ')"
        exit 1
    fi
    reload_service "$TARGET" || (( FAILED++ ))
fi

if (( FAILED > 0 )); then
    print -P ""
    print -P "%F{red}${FAILED} service(s) failed health check%f"
    exit 1
fi
