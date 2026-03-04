#!/usr/bin/env bash
# vm-smoke.sh — run CachyOS VM smoke test inside a Podman container

set -euo pipefail

ROOTFS=${1:-${ROOTFS:-/mnt/one/cachyos-root}}
PODMAN_IMAGE=${PODMAN_IMAGE:-archlinux:latest}
LOG_DIR=${LOG_DIR:-logs}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/vm-smoke-${TIMESTAMP}.log"

if [[ $EUID -ne 0 ]]; then
	echo "error: run vm-smoke.sh as root (required for Podman --privileged)" >&2
	exit 1
fi

if [[ ! -d "$ROOTFS/usr/bin" ]]; then
	echo "error: $ROOTFS is not a CachyOS rootfs (missing usr/bin)" >&2
	exit 1
fi

if ! command -v podman >/dev/null 2>&1; then
	echo "error: podman not found" >&2
	exit 1
fi

mkdir -p "$LOG_DIR"

echo "==> Pulling Podman image: $PODMAN_IMAGE"
podman pull "$PODMAN_IMAGE" >/dev/null

echo "==> Starting VM smoke test (log: $LOG_FILE)"

run_smoke() {
	podman run --rm --privileged \
		-v "$PWD":/srv/salt:ro \
		-v "$ROOTFS":/mnt/rootfs:ro \
		-w /srv/salt \
		-e ROOTFS=/mnt/rootfs \
		"$PODMAN_IMAGE" /bin/bash -lc '
            set -euo pipefail
            pacman -Sy --noconfirm --needed \
                qemu-base qemu-system-x86 edk2-ovmf btrfs-progs rsync parted dosfstools util-linux
            scripts/test-cachyos-vm.sh "${ROOTFS:-/mnt/rootfs}"
        '
}

if run_smoke |& tee "$LOG_FILE"; then
	echo "==> VM smoke test completed successfully"
else
	status=$?
	echo "==> VM smoke test failed (see $LOG_FILE)" >&2
	exit $status
fi
