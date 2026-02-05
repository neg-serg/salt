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

# Install build dependencies
dnf install -y git rpm-build tar make gcc golang nodejs npm ttfautohint python3-pip python3-fonttools python3-setuptools python3-wheel fontforge

# --- Prepare Iosevka sources ---
IOSEVKA_SOURCE_DIR="iosevka-source-${IOSEVKA_VERSION}"
git clone --depth 1 https://github.com/be5invis/Iosevka.git "${IOSEVKA_SOURCE_DIR}"
cd "${IOSEVKA_SOURCE_DIR}"
git checkout "v${IOSEVKA_VERSION}" || echo "Warning: Tag v${IOSEVKA_VERSION} not found, proceeding with master/main branch."
cd ..
tar -czf "${SOURCES_DIR}/${IOSEVKA_SOURCE_DIR}.tar.gz" "${IOSEVKA_SOURCE_DIR}"
cp "/build/iosevka-neg.toml" "${SOURCES_DIR}/iosevka-neg.toml" # /build is the bind-mounted src/salt directory

# --- Prepare Duf sources ---
DUF_SOURCE_DIR="duf-${DUF_VERSION}"
git clone --depth 1 https://github.com/neg-serg/duf.git "${DUF_SOURCE_DIR}"
cd "${DUF_SOURCE_DIR}"
# No specific tag, just use main branch
cd ..
tar -czf "${SOURCES_DIR}/duf-${DUF_VERSION}.tar.gz" "${DUF_SOURCE_DIR}"

# --- Copy spec files ---
cp /build/salt/specs/iosevka.spec "${SPECS_DIR}/iosevka-neg-fonts.spec"
cp /build/salt/specs/duf.spec "${SPECS_DIR}/duf.spec"

# --- Build Iosevka RPM ---
rpmbuild \
    --define "_topdir ${RPM_BUILD_ROOT}" \
    -ba "${SPECS_DIR}/iosevka-neg-fonts.spec"

# --- Build Duf RPM ---
rpmbuild \
    --define "_topdir ${RPM_BUILD_ROOT}" \
    -ba "${SPECS_DIR}/duf.spec"

# --- Copy resulting RPMs to a shared output directory ---
mkdir -p /build/rpms
cp "${RPMS_DIR}/x86_64/"*.rpm /build/rpms/

# Clean up (optional)
# rm -rf "${RPM_BUILD_ROOT}"

echo "RPMs built and copied to /build/rpms/"
ls -l /build/rpms/
