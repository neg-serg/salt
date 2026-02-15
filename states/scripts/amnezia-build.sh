#!/bin/bash
# shellcheck disable=SC2015  # A && B || C pattern is intentional (B=echo never fails)
set -uo pipefail
BUILD=/mnt/one/pkg/cache/amnezia
IMG=registry.fedoraproject.org/fedora-toolbox:43
PIDS=()
NAMES=()
FAILURES=0

# Clean stale source dirs (may be root-owned from previous container builds)
for d in amneziawg-go-src amneziawg-tools-src amnezia-client-src; do
    if [ -d "$BUILD/$d" ]; then
        if [ "$(id -u)" -eq 0 ]; then
            rm -rf "${BUILD:?}/$d"
        else
            podman unshare rm -rf "${BUILD:?}/$d"
        fi
    fi
done

# AmneziaWG-go
if [ ! -f "$BUILD/amneziawg-go-bin" ]; then
    (
        echo "[BUILD] amneziawg-go"
        podman run --rm -v "$BUILD:/build:Z" "$IMG" bash -c "
        dnf install -y git golang make && \
        git clone https://github.com/amnezia-vpn/amneziawg-go.git /build/amneziawg-go-src && \
        cd /build/amneziawg-go-src && \
        make && \
        cp amneziawg-go /build/amneziawg-go-bin
        " && echo "[  OK ] amneziawg-go" || { echo "[ FAIL] amneziawg-go" >&2; exit 1; }
    ) &
    PIDS+=($!); NAMES+=("amneziawg-go")
fi

# AmneziaWG-tools
if [ ! -f "$BUILD/awg-bin" ]; then
    (
        echo "[BUILD] amneziawg-tools"
        podman run --rm -v "$BUILD:/build:Z" "$IMG" bash -c "
        dnf install -y git make gcc libmnl-devel && \
        git clone https://github.com/amnezia-vpn/amneziawg-tools.git /build/amneziawg-tools-src && \
        cd /build/amneziawg-tools-src/src && \
        make && \
        cp wg /build/awg-bin
        " && echo "[  OK ] amneziawg-tools" || { echo "[ FAIL] amneziawg-tools" >&2; exit 1; }
    ) &
    PIDS+=($!); NAMES+=("amneziawg-tools")
fi

# Amnezia-VPN Client (GUI) — longest build (~1h)
if [ ! -f "$BUILD/AmneziaVPN-bin" ]; then
    (
        echo "[BUILD] amnezia-vpn"
        podman run --rm -v "$BUILD:/build:Z" "$IMG" bash -c "
        dnf install -y --disablerepo=fedora-cisco-openh264 --setopt=install_weak_deps=False \
            git cmake make gcc-c++ qt6-qtbase-devel qt6-qtsvg-devel \
            qt6-qtdeclarative-devel qt6-qttools-devel libmnl-devel libmount-devel \
            qt6-qt5compat-devel qt6-qtshadertools-devel qt6-qtmultimedia-devel \
            qt6-qtbase-static qt6-qtdeclarative-static qt6-qtremoteobjects-devel \
            libsecret-devel libstdc++-static && \
        git clone --recursive https://github.com/amnezia-vpn/amnezia-client.git /build/amnezia-client-src && \
        mkdir -p /build/amnezia-client-src/build && cd /build/amnezia-client-src/build && \
        cmake .. -DCMAKE_BUILD_TYPE=Release -DVERSION=2.1.2 && \
        make -j\$(nproc) && \
        cp client/AmneziaVPN /build/AmneziaVPN-bin
        " && echo "[  OK ] amnezia-vpn" || { echo "[ FAIL] amnezia-vpn" >&2; exit 1; }
    ) &
    PIDS+=($!); NAMES+=("amnezia-vpn")
fi

# Wait for all builds
for i in "${!PIDS[@]}"; do
    if ! wait "${PIDS[$i]}"; then
        echo "FAILED: ${NAMES[$i]}" >&2
        FAILURES=$((FAILURES + 1))
    fi
done
echo "=== Amnezia: ${#PIDS[@]} built, $FAILURES failed ==="
[ "$FAILURES" -eq 0 ]
