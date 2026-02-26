#!/bin/sh
# Greeter wrapper: immediately kills Hyprland on SIGTERM to avoid
# 5-second DRM modeset timeout hang in libaquamarine during cleanup.
# greetd sends SIGTERM when user logs in — we convert it to SIGKILL
# since the greeter doesn't need graceful shutdown.

start-hyprland -- -c /etc/greetd/hyprland-greeter.conf &
CHILD=$!
trap 'kill -9 $CHILD 2>/dev/null; wait $CHILD 2>/dev/null; exit 0' TERM
wait $CHILD
