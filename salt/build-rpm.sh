#!/bin/bash
set -euxo pipefail

# Define versions
IOSEVKA_VERSION="34.1.0"
DUF_VERSION="0.9.1" # Using current duf version from the spec file (arbitrary, can be autodetected later)

# RPM build root directory inside the container
RPM_BUILD_ROOT="/rpmbuild"
SOURCES_DIR="${RPM_BUILD_ROOT}/SOURCES"
SPECS_DIR="${RPM_BUILD_ROOT}/SPECS"
RPMS_DIR="${RPM_BUILD_ROOT}/RPMS"
SRPMS_DIR="${RPM_BUILD_ROOT}/SRPMS"

# Create RPM build directories
mkdir -p "$SOURCES_DIR" "$SPECS_DIR" "$RPMS_DIR" "$SRPMS_DIR"

# --- Build Duf RPM ---
echo "--- Preparing Duf ---"
# Install duf build dependencies
dnf install -y --skip-broken git rpm-build tar golang

DUF_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/duf-${DUF_VERSION}"
if [ ! -d "${DUF_SOURCE_DIR}" ]; then
    mkdir -p "${RPM_BUILD_ROOT}/BUILD"
    git clone --depth 1 https://github.com/neg-serg/duf.git "${DUF_SOURCE_DIR}"
fi
tar -czf "${SOURCES_DIR}/duf-${DUF_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "duf-${DUF_VERSION}"
cp /build/salt/specs/duf.spec "${SPECS_DIR}/duf.spec"

echo "--- Building Duf RPM ---"
if ls /build/rpms/duf-*.rpm 1> /dev/null 2>&1; then
    echo "Duf RPM already exists, skipping build."
else
    rpmbuild \
        --define "_topdir ${RPM_BUILD_ROOT}" \
        -ba "${SPECS_DIR}/duf.spec"

    echo "--- Copying Duf RPMs to /build/rpms/ ---"
    find "${RPMS_DIR}" -name "duf-*.rpm" -exec cp -v {} /build/rpms/ \;
fi

# --- Build Iosevka RPM ---
echo "--- Preparing Iosevka ---"
if ls /build/rpms/iosevka-neg-fonts-*.rpm 1> /dev/null 2>&1; then
    echo "Iosevka RPM already exists, skipping build."
else
    # Disable problematic repo and install iosevka build dependencies
    dnf install -y dnf-plugins-core
    dnf config-manager --set-disabled fedora-cisco-openh264 || true
    dnf install -y --skip-broken make gcc nodejs npm ttfautohint python3-pip python3-fonttools python3-setuptools python3-wheel fontforge

    IOSEVKA_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/iosevka-source-${IOSEVKA_VERSION}"
    if [ ! -d "${IOSEVKA_SOURCE_DIR}" ]; then
        mkdir -p "${RPM_BUILD_ROOT}/BUILD"
        git clone --depth 1 https://github.com/be5invis/Iosevka.git "${IOSEVKA_SOURCE_DIR}"
        cd "${IOSEVKA_SOURCE_DIR}"
        git checkout "v${IOSEVKA_VERSION}" || echo "Warning: Tag v${IOSEVKA_VERSION} not found, proceeding with master/main branch."
        cd -
    fi
    tar -czf "${SOURCES_DIR}/iosevka-source-${IOSEVKA_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "iosevka-source-${IOSEVKA_VERSION}"
    cp "/build/iosevka-neg.toml" "${SOURCES_DIR}/iosevka-neg.toml"
    cp /build/salt/specs/iosevka.spec "${SPECS_DIR}/iosevka-neg-fonts.spec"

    echo "--- Building Iosevka RPM ---"
    rpmbuild \
        --define "_topdir ${RPM_BUILD_ROOT}" \
        -ba "${SPECS_DIR}/iosevka-neg-fonts.spec"

    # Copy Iosevka RPM immediately
    echo "--- Copying Iosevka RPMs to /build/rpms/ ---"
    find "${RPMS_DIR}" -name "iosevka-neg-fonts-*.rpm" -exec cp -v {} /build/rpms/ \;
fi

# Clean up (optional)
# rm -rf "${RPM_BUILD_ROOT}"

echo "All RPMs built and copied to /build/rpms/"
ls -l /build/rpms/
