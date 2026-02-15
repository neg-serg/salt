#!/bin/bash
# Boot diagnostics script — collects info requiring root or special access
# Run: sudo bash scripts/diagnose-boot.sh > /tmp/boot-diag.txt 2>&1

set -euo pipefail
# Output path documented in usage comment above
# shellcheck disable=SC2034
OUTPUT="/tmp/boot-diag.txt"

section() { echo -e "\n===== $1 ====="; }

section "DKMS amneziawg build details"
echo "--- dkms.conf ---"
cat /var/lib/dkms/amneziawg/1.0.0/build/dkms.conf 2>/dev/null || echo "(not found)"
echo "--- make.log ---"
cat /var/lib/dkms/amneziawg/1.0.0/build/make.log 2>/dev/null || echo "(not found)"
echo "--- Build dir top-level ---"
ls -la /var/lib/dkms/amneziawg/1.0.0/build/ 2>/dev/null || echo "(not found)"
echo "--- src/ subdir ---"
ls /var/lib/dkms/amneziawg/1.0.0/build/src/ 2>/dev/null || echo "(not found)"
echo "--- linux-headers installed ---"
pacman -Q linux-cachyos-lts-headers 2>/dev/null || pacman -Q linux-headers 2>/dev/null || echo "(none)"
echo "--- Running kernel ---"
uname -r
echo "--- Available kernel source trees ---"
ls /usr/src/kernels/

section "Thunderbolt controller"
dmesg | grep -i thunderbolt || true
lspci | grep -i thunderbolt || true

section "Bluetooth"
dmesg | grep -i bluetooth || true
rfkill list 2>/dev/null || true

section "NFS statd state dir"
ls -la /var/lib/nfs/statd/ 2>/dev/null || echo "/var/lib/nfs/statd/ does not exist"
pacman -Q nfs-utils 2>/dev/null || echo "nfs-utils not installed"

section "RNNoise filter-chain (PipeWire)"
ls /usr/lib64/ladspa/librnnoise_ladspa.so 2>/dev/null && echo "RNNoise LADSPA plugin present" || echo "RNNoise LADSPA plugin MISSING"
ls /usr/lib64/lv2/rnnoise*.lv2/ 2>/dev/null || true
pw-dump 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for obj in data:
    if 'info' in obj and 'props' in obj.get('info', {}):
        props = obj['info']['props']
        name = props.get('node.name', '')
        if 'filter' in name.lower() or 'rnnoise' in name.lower():
            print(f\"  Node: {name} — {props.get('node.description', '?')}\")
" 2>/dev/null || echo "(could not parse pw-dump)"

section "ALSA HDMI device details"
aplay -l 2>/dev/null | grep -i hdmi || echo "No HDMI audio devices"
cat /proc/asound/card0/pcm0c/info 2>/dev/null || true

section "Root filesystem"
mount | grep ' / ' || true

echo -e "\n===== DONE ====="
