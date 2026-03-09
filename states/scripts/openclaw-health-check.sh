#!/usr/bin/env zsh
# OpenClaw gateway health check — called by openclaw-health.timer every 5 min.
# Checks gateway service + HTTP responsiveness, sends Telegram alerts on
# persistent failure. Deployed via Salt with Jinja2 templating.
set -eu

# ── Secrets (injected by Salt) ────────────────────────────────────────
readonly BOT_TOKEN="{{ telegram_token }}"
readonly CHAT_ID="{{ telegram_uid }}"
{% raw %}
# ── State file for alert cooldown ─────────────────────────────────────
readonly STATE_DIR="${HOME}/.cache"
readonly STATE_FILE="${STATE_DIR}/openclaw-health-state"
readonly COOLDOWN=1800  # 30 minutes in seconds

# ── Helpers ───────────────────────────────────────────────────────────

now() { date +%s }

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" }

send_telegram() {
    local msg=$1
    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        log "WARN: Telegram credentials not configured, skipping alert"
        return 0
    fi
    curl -fsSL --max-time 10 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d parse_mode=Markdown \
        -d text="${msg}" >/dev/null 2>&1 || {
        log "WARN: Failed to send Telegram alert"
        return 0
    }
}

# Read state file: outputs "first_fail_ts alert_sent" or empty
read_state() {
    [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || true
}

write_state() {
    local first_fail=$1 alert_sent=$2
    mkdir -p "$STATE_DIR"
    printf '%s %s\n' "$first_fail" "$alert_sent" > "$STATE_FILE"
}

clear_state() {
    rm -f "$STATE_FILE"
}

# ── Health checks ─────────────────────────────────────────────────────

typeset -a failures

check_service() {
    local svc=$1
    if ! systemctl --user is-active --quiet "$svc" 2>/dev/null; then
        failures+=("service \`${svc}\` is not active")
        log "FAIL: ${svc} not active"
    else
        log "  OK: ${svc} active"
    fi
}

check_gateway_http() {
    if ! curl -sf --max-time 5 http://127.0.0.1:18789/ >/dev/null 2>&1; then
        failures+=("gateway HTTP (127.0.0.1:18789) not responding")
        log "FAIL: gateway HTTP not responding"
    else
        log "  OK: gateway HTTP responding"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────

failures=()

log "Starting OpenClaw health check"

check_service "openclaw-gateway.service"
check_gateway_http

current_ts=$(now)

if (( ${#failures} == 0 )); then
    # All checks passed
    typeset state_data
    state_data=$(read_state)
    if [[ -n "$state_data" ]]; then
        # Was previously failing — send recovery notification
        log "All checks passed, clearing previous failure state"
        send_telegram "$(printf '*OpenClaw recovered*\nAll health checks passing.')"
        clear_state
    else
        log "All checks passed"
    fi
    exit 0
fi

# At least one check failed
typeset fail_summary
fail_summary=$(printf '• %s\n' "${failures[@]}")

log "Failures detected:\n${fail_summary}"

typeset state_data first_fail alert_sent
state_data=$(read_state)

if [[ -n "$state_data" ]]; then
    first_fail=${state_data%% *}
    alert_sent=${state_data##* }
else
    # First failure — record timestamp, no alert yet
    first_fail=$current_ts
    alert_sent=0
    write_state "$first_fail" "$alert_sent"
    log "First failure recorded at ${first_fail}, waiting for cooldown before alerting"
    exit 1
fi

typeset elapsed=$(( current_ts - first_fail ))

if (( elapsed > COOLDOWN && alert_sent == 0 )); then
    # Failure persisted beyond cooldown — send alert
    typeset elapsed_min=$(( elapsed / 60 ))
    send_telegram "$(printf '*OpenClaw health check FAILED*\nFailing for %d minutes:\n%s' "$elapsed_min" "$fail_summary")"
    write_state "$first_fail" 1
    log "Alert sent (failing for ${elapsed_min}m)"
elif (( alert_sent == 1 )); then
    log "Still failing, alert already sent (first failure at ${first_fail})"
else
    log "Failing for ${elapsed}s, cooldown not reached (${COOLDOWN}s)"
fi

# Update state file with current first_fail (preserve original timestamp)
write_state "$first_fail" "$alert_sent"

exit 1
{% endraw %}
