#!/bin/sh
# shellcheck source=/dev/null
[ -f /etc/profile ] && . /etc/profile
set -a
# shellcheck source=/dev/null
[ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
set +a
exec /usr/bin/start-hyprland
