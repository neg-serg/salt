#!/bin/bash
# shellcheck disable=SC2015  # A && B || C pattern is intentional (B=echo never fails)
set -uo pipefail
BUILD=/mnt/one/pkg/cache/amnezia
IMG=archlinux:latest
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
        pacman -Syu --noconfirm git go make && \
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
        pacman -Syu --noconfirm git make gcc libmnl && \
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
        pacman -Syu --noconfirm \
            git cmake make gcc qt6-base qt6-svg \
            qt6-declarative qt6-tools libmnl util-linux \
            qt6-5compat qt6-shadertools qt6-multimedia \
            qt6-remoteobjects libsecret && \
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
