#!/bin/sh
# Session wrapper: sources environment then starts Hyprland.
# Logs timestamps to journal for login delay diagnosis.
logger -t greetd-session-wrapper "session-wrapper started"

# shellcheck source=/dev/null
[ -f /etc/profile ] && . /etc/profile
logger -t greetd-session-wrapper "sourced /etc/profile"

set -a
# shellcheck source=/dev/null
[ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
set +a
logger -t greetd-session-wrapper "sourced 10-user.conf, exec start-hyprland"

exec /usr/bin/start-hyprland
