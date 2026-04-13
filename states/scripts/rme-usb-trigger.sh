#!/usr/bin/env bash
# Triggered by udev when the RME ADI-2/4 Pro SE USB device appears.
# Restarts pw-restore-links.service to re-establish PipeWire loopback links
# after suspend/resume or USB reconnect.

set -euo pipefail

USER="neg"
UID_NUM=1000
export XDG_RUNTIME_DIR="/run/user/${UID_NUM}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Guard: WirePlumber must be running
if ! systemctl --user --machine="${USER}@" is-active --quiet wireplumber.service 2>/dev/null; then
    exit 0
fi

# Guard: User session must be active
if ! loginctl show-user "${USER}" 2>/dev/null | grep -qE '^State=active|^State=online'; then
    exit 0
fi

# Fire-and-forget: start the service.
# The service's ExecStartPre sleep 3 waits for nodes to enumerate.
systemctl --user --machine="${USER}@" start pw-restore-links.service 2>/dev/null || true
