#!/bin/sh
# Session wrapper: sources environment then launches the requested session.
# All greetd sessions MUST go through this wrapper so that /etc/profile
# and environment.d are sourced — greetd/PAM only provides a bare env.

# shellcheck source=/dev/null
[ -f /etc/profile ] && . /etc/profile

set -a
# shellcheck source=/dev/null
[ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
set +a

# Accept session command as arguments; default to start-hyprland
if [ $# -gt 0 ]; then
    exec "$@"
else
    exec /usr/bin/start-hyprland
fi
