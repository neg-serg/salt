#!/usr/bin/env bash
# Auto-generate /etc/fancontrol from detected hwmon devices.
# Discovers nct6775/nct6799 (motherboard) and optionally amdgpu PWM channels,
# then writes a fancontrol config for all active fans.
#
# Configuration via environment variables (set by fancontrol-setup.service):
#   MIN_TEMP, MAX_TEMP, MIN_PWM, MAX_PWM, HYST, INTERVAL, ALLOW_STOP
#   GPU_ENABLE, GPU_MIN_TEMP, GPU_MAX_TEMP, GPU_MIN_PWM, GPU_MAX_PWM, GPU_HYST
set -euo pipefail

# Defaults (overridden by env)
: "${MIN_TEMP:=35}"
: "${MAX_TEMP:=75}"
: "${MIN_PWM:=70}"
: "${MAX_PWM:=255}"
: "${HYST:=3}"
: "${INTERVAL:=2}"
: "${ALLOW_STOP:=false}"
: "${GPU_ENABLE:=false}"
: "${GPU_MIN_TEMP:=50}"
: "${GPU_MAX_TEMP:=85}"
: "${GPU_MIN_PWM:=70}"
: "${GPU_MAX_PWM:=255}"
: "${GPU_HYST:=3}"

FANCONTROL_CONF="/etc/fancontrol"

# Find hwmon device by chip name pattern (nct67* for motherboard, amdgpu for GPU)
find_hwmon() {
    local pattern="$1"
    for d in /sys/class/hwmon/hwmon*; do
        local name
        name=$(cat "$d/name" 2>/dev/null) || continue
        if [[ "$name" =~ $pattern ]]; then
            basename "$d"
            return 0
        fi
    done
    return 1
}

# Get devpath relative to /sys/ (what fancontrol expects)
get_devpath() {
    local hw="$1"
    readlink -f "/sys/class/hwmon/$hw/device" | sed 's|^/sys/||'
}

# Get chip name
get_devname() {
    cat "/sys/class/hwmon/$1/name"
}

# Enumerate active PWM channels (those whose corresponding fan is spinning or present)
get_active_pwm_channels() {
    local hw="$1"
    for pwm_en in "/sys/class/hwmon/$hw"/pwm[0-9]*_enable; do
        [ -e "$pwm_en" ] || continue
        local n="${pwm_en##*/}"
        n="${n%%_enable}"   # e.g. "pwm1"
        local idx="${n#pwm}"
        local fan_input="/sys/class/hwmon/$hw/fan${idx}_input"
        # Include channel if fan input exists (even if RPM is 0 — fan may be stopped)
        if [ -e "$fan_input" ]; then
            echo "$n"
        fi
    done
}

# Set PWM channel to manual mode (1 = manual, 2 = auto, 5 = smart fan IV)
enable_manual_pwm() {
    local hw="$1" channel="$2"
    local en="/sys/class/hwmon/$hw/${channel}_enable"
    if [ -w "$en" ]; then
        echo 1 > "$en" 2>/dev/null || true
    fi
}

echo "fancontrol-setup: discovering hwmon devices..."

# --- Motherboard chip (nct6775 / nct6799 / etc.) ---
MB_HW=$(find_hwmon '^nct' || true)
if [ -z "$MB_HW" ]; then
    echo "WARNING: no nct67xx hwmon device found. Trying to load nct6775 module..."
    modprobe nct6775 2>/dev/null || true
    sleep 1
    MB_HW=$(find_hwmon '^nct' || true)
fi

if [ -z "$MB_HW" ]; then
    echo "ERROR: no motherboard fan controller found, cannot generate fancontrol" >&2
    exit 1
fi

echo "  Motherboard: $MB_HW ($(get_devname "$MB_HW"))"
MB_DEVPATH=$(get_devpath "$MB_HW")

DEVPATH_ENTRIES="$MB_HW=$MB_DEVPATH"
DEVNAME_ENTRIES="$MB_HW=$(get_devname "$MB_HW")"

# Use CPU temp sensor: prefer k10temp (AMD) or coretemp (Intel)
TEMP_HW=$(find_hwmon '^k10temp$' || find_hwmon '^coretemp$' || echo "$MB_HW")
if [ "$TEMP_HW" != "$MB_HW" ]; then
    TEMP_DEVPATH=$(get_devpath "$TEMP_HW")
    DEVPATH_ENTRIES="$DEVPATH_ENTRIES $TEMP_HW=$TEMP_DEVPATH"
    DEVNAME_ENTRIES="$DEVNAME_ENTRIES $TEMP_HW=$(get_devname "$TEMP_HW")"
    TEMP_INPUT="$TEMP_HW/temp1_input"
    echo "  CPU temp: $TEMP_HW ($(get_devname "$TEMP_HW"))"
else
    # Fallback to motherboard temp sensor 2 (usually CPUTIN on NCT chips)
    if [ -f "/sys/class/hwmon/$MB_HW/temp2_input" ]; then
        TEMP_INPUT="$MB_HW/temp2_input"
    else
        TEMP_INPUT="$MB_HW/temp1_input"
    fi
fi

# Collect motherboard fan channels
FCTEMPS="" FCFANS="" MINTEMP_ENTRIES="" MAXTEMP_ENTRIES=""
MINSTART="" MINSTOP="" MAXPWM_ENTRIES="" MINPWM_ENTRIES=""

for ch in $(get_active_pwm_channels "$MB_HW"); do
    idx="${ch#pwm}"
    enable_manual_pwm "$MB_HW" "$ch"

    entry="$MB_HW/$ch"
    FCTEMPS="${FCTEMPS:+$FCTEMPS }${entry}=${TEMP_INPUT}"
    FCFANS="${FCFANS:+$FCFANS }${entry}=$MB_HW/fan${idx}_input"
    MINTEMP_ENTRIES="${MINTEMP_ENTRIES:+$MINTEMP_ENTRIES }${entry}=${MIN_TEMP}"
    MAXTEMP_ENTRIES="${MAXTEMP_ENTRIES:+$MAXTEMP_ENTRIES }${entry}=${MAX_TEMP}"
    MINSTART="${MINSTART:+$MINSTART }${entry}=${MIN_PWM}"
    MINSTOP="${MINSTOP:+$MINSTOP }${entry}=${MIN_PWM}"
    MAXPWM_ENTRIES="${MAXPWM_ENTRIES:+$MAXPWM_ENTRIES }${entry}=${MAX_PWM}"
    MINPWM_ENTRIES="${MINPWM_ENTRIES:+$MINPWM_ENTRIES }${entry}=${MIN_PWM}"
    echo "  Fan channel: $entry → $TEMP_INPUT"
done

# --- GPU (amdgpu) ---
if [ "$GPU_ENABLE" = "true" ]; then
    GPU_HW=$(find_hwmon '^amdgpu$' || true)
    # Pick the amdgpu device that actually has pwm1_enable
    if [ -n "$GPU_HW" ]; then
        # There may be multiple amdgpu hwmon; find the one with PWM
        for d in /sys/class/hwmon/hwmon*; do
            local_name=$(cat "$d/name" 2>/dev/null) || continue
            if [ "$local_name" = "amdgpu" ] && [ -f "$d/pwm1_enable" ]; then
                GPU_HW=$(basename "$d")
                break
            fi
        done
    fi

    if [ -n "$GPU_HW" ] && [ -f "/sys/class/hwmon/$GPU_HW/pwm1_enable" ]; then
        echo "  GPU: $GPU_HW (amdgpu)"
        GPU_DEVPATH=$(get_devpath "$GPU_HW")
        DEVPATH_ENTRIES="$DEVPATH_ENTRIES $GPU_HW=$GPU_DEVPATH"
        DEVNAME_ENTRIES="$DEVNAME_ENTRIES $GPU_HW=amdgpu"

        enable_manual_pwm "$GPU_HW" "pwm1"

        entry="$GPU_HW/pwm1"
        gpu_temp="$GPU_HW/temp1_input"
        FCTEMPS="${FCTEMPS:+$FCTEMPS }${entry}=${gpu_temp}"
        FCFANS="${FCFANS:+$FCFANS }${entry}=$GPU_HW/fan1_input"
        MINTEMP_ENTRIES="${MINTEMP_ENTRIES:+$MINTEMP_ENTRIES }${entry}=${GPU_MIN_TEMP}"
        MAXTEMP_ENTRIES="${MAXTEMP_ENTRIES:+$MAXTEMP_ENTRIES }${entry}=${GPU_MAX_TEMP}"
        MINSTART="${MINSTART:+$MINSTART }${entry}=${GPU_MIN_PWM}"
        MINSTOP="${MINSTOP:+$MINSTOP }${entry}=${GPU_MIN_PWM}"
        MAXPWM_ENTRIES="${MAXPWM_ENTRIES:+$MAXPWM_ENTRIES }${entry}=${GPU_MAX_PWM}"
        MINPWM_ENTRIES="${MINPWM_ENTRIES:+$MINPWM_ENTRIES }${entry}=${GPU_MIN_PWM}"
        echo "  GPU fan: $entry → $gpu_temp"
    else
        echo "  WARNING: no amdgpu PWM device found, skipping GPU fan control"
    fi
fi

# --- Write /etc/fancontrol ---
echo "fancontrol-setup: writing $FANCONTROL_CONF"

cat > "$FANCONTROL_CONF" <<EOF
# Auto-generated by fancontrol-setup.sh — do not edit manually
INTERVAL=$INTERVAL
DEVPATH=$DEVPATH_ENTRIES
DEVNAME=$DEVNAME_ENTRIES
FCTEMPS=$FCTEMPS
FCFANS=$FCFANS
MINTEMP=$MINTEMP_ENTRIES
MAXTEMP=$MAXTEMP_ENTRIES
MINSTART=$MINSTART
MINSTOP=$MINSTOP
MAXPWM=$MAXPWM_ENTRIES
MINPWM=$MINPWM_ENTRIES
EOF

echo "fancontrol-setup: done"
