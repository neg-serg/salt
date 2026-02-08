#!/bin/bash
set -euxo pipefail

HY3_TAG="hl0.51.0"
OUTPUT_DIR="/build/output"

if [ -f "${OUTPUT_DIR}/libhy3.so" ]; then
    echo "libhy3.so already exists, skipping."
    exit 0
fi

# Enable solopasha/hyprland COPR for hyprland-devel
dnf install -y 'dnf-command(copr)'
dnf copr enable -y solopasha/hyprland
dnf install -y --skip-broken \
    git cmake gcc-c++ pkgconf-pkg-config \
    hyprland-devel \
    aquamarine-devel \
    hyprlang-devel \
    hyprutils-devel \
    hyprgraphics-devel \
    pixman-devel \
    pango-devel \
    cairo-devel

# Clone hy3
git clone --depth 1 --branch "${HY3_TAG}" https://github.com/outfoxxed/hy3.git /tmp/hy3
cd /tmp/hy3

# Build
cmake -B build
cmake --build build --parallel "$(nproc)"

# Copy result
cp build/libhy3.so "${OUTPUT_DIR}/libhy3.so"
echo "hy3 built successfully"
