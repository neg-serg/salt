#!/usr/bin/env zsh
set -uo pipefail
BUILD=${BUILD:?BUILD env var required}
IMG=archlinux:latest
# Build a container mirrorlist from host mirrors, excluding CachyOS-specific ones
# (CachyOS mirrors serve x86-64-v3/v4 packages incompatible with vanilla archlinux image)
MIRRORLIST="$BUILD/.mirrorlist"
grep -v 'cachyos\|cachy-arch' /etc/pacman.d/mirrorlist > "$MIRRORLIST" 2>/dev/null \
    || echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > "$MIRRORLIST"
PODMAN=(podman run --rm --network=host -v "$BUILD:/build:Z"
        -v "$MIRRORLIST:/etc/pacman.d/mirrorlist:ro")
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
        "${PODMAN[@]}" "$IMG" bash -c "
        for _p in 1 2 3; do pacman -Syu --noconfirm git go make && break || sleep 5; done && \
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
        "${PODMAN[@]}" "$IMG" bash -c "
        for _p in 1 2 3; do pacman -Syu --noconfirm git make gcc libmnl && break || sleep 5; done && \
        git clone https://github.com/amnezia-vpn/amneziawg-tools.git /build/amneziawg-tools-src && \
        cd /build/amneziawg-tools-src/src && \
        make && \
        cp wg /build/awg-bin
        " && echo "[  OK ] amneziawg-tools" || { echo "[ FAIL] amneziawg-tools" >&2; exit 1; }
    ) &
    PIDS+=($!); NAMES+=("amneziawg-tools")
fi

# Amnezia-VPN Client + Service — built together via cmake
if [ ! -f "$BUILD/AmneziaVPN-bin" ] || [ ! -f "$BUILD/AmneziaVPN-service-bin" ]; then
    (
        echo "[BUILD] amnezia-vpn (client + service)"
        "${PODMAN[@]}" "$IMG" bash -c "
        sed -i 's/^#\\?ParallelDownloads.*/ParallelDownloads = 3/' /etc/pacman.conf && \
        for _p in 1 2 3; do pacman -Syu --noconfirm \
            git cmake make gcc qt6-base qt6-svg \
            qt6-declarative qt6-tools libmnl util-linux \
            qt6-5compat qt6-shadertools qt6-multimedia \
            qt6-remoteobjects libsecret && break || sleep 5; done && \
        git config --global http.postBuffer 524288000 && \
        git config --global http.lowSpeedLimit 1000 && \
        git config --global http.lowSpeedTime 30 && \
        git clone --depth 1 --branch ${AMNEZIA_VERSION:?AMNEZIA_VERSION env var required} \
            https://github.com/amnezia-vpn/amnezia-client.git /build/amnezia-client-src && \
        cd /build/amnezia-client-src && \
        for _try in 1 2 3 4 5; do git submodule update --init --depth 1 --jobs 1 && break || sleep 5; done && \
        mkdir -p build && cd build && \
        /usr/lib/qt6/bin/qt-cmake -S /build/amnezia-client-src -DCMAKE_BUILD_TYPE=Release && \
        cmake --build . -j\$(nproc) --config Release && \
        cp client/AmneziaVPN /build/AmneziaVPN-bin && \
        cp service/server/AmneziaVPN-service /build/AmneziaVPN-service-bin
        " && echo "[  OK ] amnezia-vpn" || { echo "[ FAIL] amnezia-vpn" >&2; exit 1; }
    ) &
    PIDS+=($!); NAMES+=("amnezia-vpn")
fi

# Wait for all builds
if [ ${#PIDS[@]} -eq 0 ]; then
    echo "=== Amnezia: all binaries already cached ==="
    exit 0
fi
for i in {1..${#PIDS[@]}}; do
    if ! wait "${PIDS[$i]}"; then
        echo "FAILED: ${NAMES[$i]}" >&2
        FAILURES=$((FAILURES + 1))
    fi
done
echo "=== Amnezia: ${#PIDS[@]} built, $FAILURES failed ==="
[ "$FAILURES" -eq 0 ]
