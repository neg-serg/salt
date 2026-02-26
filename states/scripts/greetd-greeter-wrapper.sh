#!/bin/sh
# Greeter wrapper: immediately kills Hyprland on SIGTERM to avoid
# 5-second DRM modeset timeout hang in libaquamarine during cleanup.
# greetd sends SIGTERM when user logs in — we convert it to SIGKILL
# since the greeter doesn't need graceful shutdown.
#
# start-hyprland forks a watchdog parent + Hyprland child. Killing only
# the watchdog ($CHILD) causes Hyprland to detect the broken watchdog
# pipe and initiate graceful DRM cleanup (5-second modeset timeout in
# kernel D-state). setsid isolates both processes in their own process
# group so we can SIGKILL the entire group at once, preventing any
# cleanup code from running.

ulimit -c 0
setsid start-hyprland -- -c /etc/greetd/hyprland-greeter.conf &
CHILD=$!
trap 'kill -9 -$CHILD 2>/dev/null; wait $CHILD 2>/dev/null; exit 0' TERM
wait $CHILD
