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
DUF_RPM_NAME="duf-${DUF_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "duf" ]]; then
    echo "--- Preparing Duf ---"
    if [ -f "/build/rpms/${DUF_RPM_NAME}" ]; then
        echo "Duf RPM (${DUF_RPM_NAME}) already exists, skipping."
    else
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
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/duf.spec"

        echo "--- Copying Duf RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "duf-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Massren RPM ---
MASSREN_VERSION="1.5.6"
MASSREN_RPM_NAME="massren-${MASSREN_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "massren" ]]; then
    echo "--- Preparing Massren ---"
    if [ -f "/build/rpms/${MASSREN_RPM_NAME}" ]; then
        echo "Massren RPM (${MASSREN_RPM_NAME}) already exists, skipping."
    else
        # Install massren build dependencies (same as duf)
        dnf install -y --skip-broken git rpm-build tar golang

        MASSREN_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/massren-${MASSREN_VERSION}"
        if [ ! -d "${MASSREN_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 https://github.com/laurent22/massren.git "${MASSREN_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/massren-${MASSREN_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "massren-${MASSREN_VERSION}"
        cp /build/salt/specs/massren.spec "${SPECS_DIR}/massren.spec"

        echo "--- Building Massren RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/massren.spec"

        echo "--- Copying Massren RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "massren-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Iosevka RPM ---
IOSEVKA_RPM_NAME="iosevka-neg-fonts-${IOSEVKA_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "iosevka" ]]; then
    echo "--- Preparing Iosevka ---"
    if [ -f "/build/rpms/${IOSEVKA_RPM_NAME}" ]; then
        echo "Iosevka RPM (${IOSEVKA_RPM_NAME}) already exists, skipping."
    else
        # Install iosevka build dependencies
        dnf install -y dnf-plugins-core
        rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo
        dnf install -y --skip-broken make gcc git nodejs npm rpm-build ttfautohint python3-pip python3-fonttools python3-setuptools python3-wheel fontforge

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
fi

# Clean up (optional)
# rm -rf "${RPM_BUILD_ROOT}"

echo "All RPMs built and copied to /build/rpms/"
ls -l /build/rpms/
