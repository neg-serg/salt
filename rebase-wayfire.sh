#!/bin/bash
set -e

IMAGE="ghcr.io/wayblueorg/wayfire:latest"

step_file="/tmp/.rebase-wayfire-step"
step=$(cat "$step_file" 2>/dev/null || echo 1)

case "$step" in
  1)
    echo "=== Step 1/2: Rebase to unsigned image ==="
    rpm-ostree rebase "ostree-unverified-registry:${IMAGE}"
    echo 2 > "$step_file"
    echo ""
    echo "Done. Reboot now, then run this script again:"
    echo "  systemctl reboot"
    ;;
  2)
    echo "=== Step 2/2: Rebase to signed image ==="
    rpm-ostree rebase "ostree-image-signed:docker://${IMAGE}"
    rm -f "$step_file"
    echo ""
    echo "Done. Reboot, then apply config:"
    echo "  systemctl reboot"
    echo "  # after reboot:"
    echo "  ./apply_config.sh"
    ;;
esac
