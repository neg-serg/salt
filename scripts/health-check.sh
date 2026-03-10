#!/usr/bin/env bash
# health-check.sh — check health of all Salt-managed services
#
# Usage:
#   scripts/health-check.sh            # colored table
#   scripts/health-check.sh --json     # JSON output
#   scripts/health-check.sh --quiet    # exit code only (0=healthy, 1=unhealthy)

set -euo pipefail

JSON_MODE=false
QUIET_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --quiet|-q) QUIET_MODE=true ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

unhealthy=0
results=()

check_system_service() {
    local svc="$1"
    local expected="${2:-active}"
    local actual
    actual=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
    local status="healthy"
    if [ "$actual" != "$expected" ]; then
        status="unhealthy"
        unhealthy=$((unhealthy + 1))
    fi
    results+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$svc" "system" "$expected" "$actual" "-" "$status")")
}

check_user_service() {
    local svc="$1"
    local expected="${2:-active}"
    local actual
    actual=$(systemctl --user is-active "$svc" 2>/dev/null || echo "inactive")
    local status="healthy"
    if [ "$actual" != "$expected" ]; then
        status="unhealthy"
        unhealthy=$((unhealthy + 1))
    fi
    results+=("$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$svc" "user" "$expected" "$actual" "-" "$status")")
}

# ── System services ──────────────────────────────────────────────────────
SYSTEM_SERVICES=(
    sshd
    unbound
    cronie
    NetworkManager
)

# Optional system services (may not be installed)
OPTIONAL_SYSTEM=(
    jellyfin
    transmission
    adguardhome
    ollama
    llama-embed
    loki
    promtail
    grafana
    netdata
    samba
    bitcoind
)

for svc in "${SYSTEM_SERVICES[@]}"; do
    check_system_service "$svc"
done

for svc in "${OPTIONAL_SYSTEM[@]}"; do
    # Only check if the unit file exists
    if systemctl cat "$svc" &>/dev/null; then
        check_system_service "$svc"
    fi
done

# ── User services ────────────────────────────────────────────────────────
# Parse from user_services.yaml
USER_SERVICES_FILE="${PROJECT_DIR}/states/data/user_services.yaml"
if [ -f "$USER_SERVICES_FILE" ]; then
    while IFS= read -r svc; do
        [ -n "$svc" ] && check_user_service "$svc"
    done < <(grep -oP '^\s+- \K\S+' <(sed -n '/^enable_services:/,/^[^ ]/p' "$USER_SERVICES_FILE") 2>/dev/null || true)

    while IFS= read -r timer; do
        [ -n "$timer" ] && check_user_service "$timer"
    done < <(grep -oP '^\s+- \K\S+' <(sed -n '/^enable_now_timers:/,/^[^ ]/p' "$USER_SERVICES_FILE") 2>/dev/null || true)
fi

# ── HTTP healthchecks ────────────────────────────────────────────────────
declare -A HEALTHCHECKS=(
    [loki]="3100:/ready"
    [promtail]="9080:/ready"
    [grafana]="3030:/api/health"
    [adguardhome]="3000:/"
    [ollama]="11434:/api/tags"
    [llama-embed]="11435:/health"
)

for name in "${!HEALTHCHECKS[@]}"; do
    IFS=: read -r port path <<< "${HEALTHCHECKS[$name]}"
    # Find the matching result entry and add health info
    for i in "${!results[@]}"; do
        entry="${results[$i]}"
        entry_name="${entry%%	*}"
        if [ "$entry_name" = "$name" ]; then
            http_ok="-"
            if curl -sf --connect-timeout 2 --max-time 5 "http://127.0.0.1:${port}${path}" >/dev/null 2>&1; then
                http_ok="ok"
            else
                entry_actual=$(echo "$entry" | cut -f4)
                if [ "$entry_actual" = "active" ]; then
                    http_ok="FAIL"
                    unhealthy=$((unhealthy + 1))
                else
                    http_ok="skip"
                fi
            fi
            # Replace the health field (field 5 of 6)
            results[i]=$(echo "$entry" | awk -F'\t' -v h="$http_ok" 'BEGIN{OFS="\t"} {$5=h; print}')
            break
        fi
    done
done

# ── Output ───────────────────────────────────────────────────────────────
if $QUIET_MODE; then
    exit $(( unhealthy > 0 ? 1 : 0 ))
fi

if $JSON_MODE; then
    echo "["
    first=true
    for entry in "${results[@]}"; do
        IFS=$'\t' read -r name type expected actual health status <<< "$entry"
        $first || echo ","
        first=false
        printf '  {"service":"%s","type":"%s","expected":"%s","actual":"%s","health":"%s","status":"%s"}' \
            "$name" "$type" "$expected" "$actual" "$health" "$status"
    done
    echo ""
    echo "]"
    exit $(( unhealthy > 0 ? 1 : 0 ))
fi

# Table output
printf '%b%-30s %-8s %-10s %-10s %-8s%b\n' "$BOLD" "SERVICE" "TYPE" "EXPECTED" "ACTUAL" "HEALTH" "$NC"
printf '%.0s─' {1..70}
echo ""

for entry in "${results[@]}"; do
    IFS=$'\t' read -r name type expected actual health status <<< "$entry"
    if [ "$status" = "healthy" ]; then
        color="$GREEN"
    else
        color="$RED"
    fi
    printf '%b%-30s %-8s %-10s %-10s %-8s%b\n' "$color" "$name" "$type" "$expected" "$actual" "$health" "$NC"
done

echo ""
if [ "$unhealthy" -eq 0 ]; then
    printf '%b%s%b\n' "$GREEN" "All services healthy" "$NC"
else
    printf '%b%d unhealthy service(s)%b\n' "$RED" "$unhealthy" "$NC"
fi

exit $(( unhealthy > 0 ? 1 : 0 ))
