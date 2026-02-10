#!/bin/bash
set -euxo pipefail

# Define versions
IOSEVKA_VERSION="34.1.0"
DUF_VERSION="0.9.1"
RAISE_VERSION="0.1.0"
PIPEMIXER_VERSION="0.4.0"
RICHCOLORS_VERSION="0.1.0"
NEG_PRETTY_PRINTER_VERSION="0.1.0"
CHOOSE_VERSION="1.3.7"
OUCH_VERSION="0.6.1"
HTMLQ_VERSION="0.4.0"
ERDTREE_VERSION="3.1.2"
VIU_VERSION="1.6.1"
FCLONES_VERSION="0.35.0"
GREX_VERSION="1.4.6"
KMON_VERSION="1.7.1"
JUJUTSU_VERSION="0.38.0"
ZFXTOP_VERSION="0.3.2"
PUP_VERSION="0.4.0"
SCC_VERSION="3.6.0"
CTOP_VERSION="0.7.7"
DIVE_VERSION="0.13.1"
ZK_VERSION="0.15.2"
GIT_FILTER_REPO_VERSION="2.47.0"
EPR_VERSION="2.4.15"
LUTGEN_VERSION="0.12.1"
TAPLO_VERSION="0.10.0"
GIST_VERSION="6.0.0"
XXH_VERSION="0.8.14"
NERDCTL_VERSION="2.2.1"
RAPIDGZIP_VERSION="0.16.0"
SCOUR_VERSION="0.38.2"
BANDWHICH_VERSION="0.23.1"
XH_VERSION="0.25.3"
CURLIE_VERSION="1.8.2"
DOGGO_VERSION="1.1.2"
CARAPACE_VERSION="1.6.1"
WL_CLIP_PERSIST_VERSION="0.5.0"
WALLUST_VERSION="3.3.0"
QUICKSHELL_VERSION="0.2.1"
SWAYOSD_VERSION="0.3.0"
XDG_TERMFILECHOOSER_VERSION="0.4.0"
BUCKLESPRING_VERSION="1.5.1"
TAOUP_VERSION="1.1.23"
NEWSRAFT_VERSION="0.26"

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

# --- Build Raise RPM ---
RAISE_RPM_NAME="raise-${RAISE_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "raise" ]]; then
    echo "--- Preparing Raise ---"
    if [ -f "/build/rpms/${RAISE_RPM_NAME}" ]; then
        echo "Raise RPM (${RAISE_RPM_NAME}) already exists, skipping."
    else
        # Install raise build dependencies
        dnf install -y --skip-broken git rpm-build tar rust cargo

        RAISE_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/raise-${RAISE_VERSION}"
        if [ ! -d "${RAISE_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 https://github.com/neg-serg/raise.git "${RAISE_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/raise-${RAISE_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "raise-${RAISE_VERSION}"
        cp /build/salt/specs/raise.spec "${SPECS_DIR}/raise.spec"

        echo "--- Building Raise RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/raise.spec"

        echo "--- Copying Raise RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "raise-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Pipemixer RPM ---
PIPEMIXER_RPM_NAME="pipemixer-${PIPEMIXER_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "pipemixer" ]]; then
    echo "--- Preparing Pipemixer ---"
    if [ -f "/build/rpms/${PIPEMIXER_RPM_NAME}" ]; then
        echo "Pipemixer RPM (${PIPEMIXER_RPM_NAME}) already exists, skipping."
    else
        # Install pipemixer build dependencies
        dnf install -y --skip-broken git rpm-build tar gcc meson ninja-build pkgconf-pkg-config pipewire-devel ncurses-devel inih-devel

        PIPEMIXER_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/pipemixer-${PIPEMIXER_VERSION}"
        if [ ! -d "${PIPEMIXER_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${PIPEMIXER_VERSION}" https://github.com/heather7283/pipemixer.git "${PIPEMIXER_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/pipemixer-${PIPEMIXER_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "pipemixer-${PIPEMIXER_VERSION}"
        cp /build/salt/specs/pipemixer.spec "${SPECS_DIR}/pipemixer.spec"

        echo "--- Building Pipemixer RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/pipemixer.spec"

        echo "--- Copying Pipemixer RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "pipemixer-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Richcolors RPM ---
RICHCOLORS_RPM_NAME="richcolors-${RICHCOLORS_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "richcolors" ]]; then
    echo "--- Preparing Richcolors ---"
    if [ -f "/build/rpms/${RICHCOLORS_RPM_NAME}" ]; then
        echo "Richcolors RPM (${RICHCOLORS_RPM_NAME}) already exists, skipping."
    else
        # Install richcolors build dependencies
        dnf install -y --skip-broken git rpm-build tar

        RICHCOLORS_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/richcolors-${RICHCOLORS_VERSION}"
        if [ ! -d "${RICHCOLORS_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 https://github.com/Rizen54/richcolors.git "${RICHCOLORS_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/richcolors-${RICHCOLORS_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "richcolors-${RICHCOLORS_VERSION}"
        cp /build/salt/specs/richcolors.spec "${SPECS_DIR}/richcolors.spec"

        echo "--- Building Richcolors RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/richcolors.spec"

        echo "--- Copying Richcolors RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "richcolors-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build neg-pretty-printer RPM ---
NEG_PRETTY_PRINTER_RPM_NAME="neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "neg-pretty-printer" ]]; then
    echo "--- Preparing neg-pretty-printer ---"
    if [ -f "/build/rpms/${NEG_PRETTY_PRINTER_RPM_NAME}" ]; then
        echo "neg-pretty-printer RPM (${NEG_PRETTY_PRINTER_RPM_NAME}) already exists, skipping."
    else
        # Install neg-pretty-printer build dependencies
        dnf install -y --skip-broken rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel

        NEG_PP_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}"
        if [ ! -d "${NEG_PP_SOURCE_DIR}" ]; then
            mkdir -p "${NEG_PP_SOURCE_DIR}"
            cp -r /build/pretty-printer/* /build/pretty-printer/.gitignore "${NEG_PP_SOURCE_DIR}/" 2>/dev/null || true
        fi
        tar -czf "${SOURCES_DIR}/neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}"
        cp /build/salt/specs/neg-pretty-printer.spec "${SPECS_DIR}/neg-pretty-printer.spec"

        echo "--- Building neg-pretty-printer RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/neg-pretty-printer.spec"

        echo "--- Copying neg-pretty-printer RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "neg-pretty-printer-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Choose RPM ---
CHOOSE_RPM_NAME="choose-${CHOOSE_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "choose" ]]; then
    echo "--- Preparing Choose ---"
    if [ -f "/build/rpms/${CHOOSE_RPM_NAME}" ]; then
        echo "Choose RPM (${CHOOSE_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        CHOOSE_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/choose-${CHOOSE_VERSION}"
        if [ ! -d "${CHOOSE_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${CHOOSE_VERSION}" https://github.com/theryangeary/choose.git "${CHOOSE_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/choose-${CHOOSE_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "choose-${CHOOSE_VERSION}"
        cp /build/salt/specs/choose.spec "${SPECS_DIR}/choose.spec"

        echo "--- Building Choose RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/choose.spec"

        echo "--- Copying Choose RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "choose-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Ouch RPM ---
OUCH_RPM_NAME="ouch-${OUCH_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "ouch" ]]; then
    echo "--- Preparing Ouch ---"
    if [ -f "/build/rpms/${OUCH_RPM_NAME}" ]; then
        echo "Ouch RPM (${OUCH_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo gcc-c++ clang clang-devel

        OUCH_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/ouch-${OUCH_VERSION}"
        if [ ! -d "${OUCH_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "${OUCH_VERSION}" https://github.com/ouch-org/ouch.git "${OUCH_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/ouch-${OUCH_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "ouch-${OUCH_VERSION}"
        cp /build/salt/specs/ouch.spec "${SPECS_DIR}/ouch.spec"

        echo "--- Building Ouch RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/ouch.spec"

        echo "--- Copying Ouch RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "ouch-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Htmlq RPM ---
HTMLQ_RPM_NAME="htmlq-${HTMLQ_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "htmlq" ]]; then
    echo "--- Preparing Htmlq ---"
    if [ -f "/build/rpms/${HTMLQ_RPM_NAME}" ]; then
        echo "Htmlq RPM (${HTMLQ_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        HTMLQ_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/htmlq-${HTMLQ_VERSION}"
        if [ ! -d "${HTMLQ_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${HTMLQ_VERSION}" https://github.com/mgdm/htmlq.git "${HTMLQ_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/htmlq-${HTMLQ_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "htmlq-${HTMLQ_VERSION}"
        cp /build/salt/specs/htmlq.spec "${SPECS_DIR}/htmlq.spec"

        echo "--- Building Htmlq RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/htmlq.spec"

        echo "--- Copying Htmlq RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "htmlq-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Erdtree RPM ---
ERDTREE_RPM_NAME="erdtree-${ERDTREE_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "erdtree" ]]; then
    echo "--- Preparing Erdtree ---"
    if [ -f "/build/rpms/${ERDTREE_RPM_NAME}" ]; then
        echo "Erdtree RPM (${ERDTREE_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        ERDTREE_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/erdtree-${ERDTREE_VERSION}"
        if [ ! -d "${ERDTREE_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${ERDTREE_VERSION}" https://github.com/solidiquis/erdtree.git "${ERDTREE_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/erdtree-${ERDTREE_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "erdtree-${ERDTREE_VERSION}"
        cp /build/salt/specs/erdtree.spec "${SPECS_DIR}/erdtree.spec"

        echo "--- Building Erdtree RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/erdtree.spec"

        echo "--- Copying Erdtree RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "erdtree-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Viu RPM ---
VIU_RPM_NAME="viu-${VIU_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "viu" ]]; then
    echo "--- Preparing Viu ---"
    if [ -f "/build/rpms/${VIU_RPM_NAME}" ]; then
        echo "Viu RPM (${VIU_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        VIU_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/viu-${VIU_VERSION}"
        if [ ! -d "${VIU_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${VIU_VERSION}" https://github.com/atanunq/viu.git "${VIU_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/viu-${VIU_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "viu-${VIU_VERSION}"
        cp /build/salt/specs/viu.spec "${SPECS_DIR}/viu.spec"

        echo "--- Building Viu RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/viu.spec"

        echo "--- Copying Viu RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "viu-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Fclones RPM ---
FCLONES_RPM_NAME="fclones-${FCLONES_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "fclones" ]]; then
    echo "--- Preparing Fclones ---"
    if [ -f "/build/rpms/${FCLONES_RPM_NAME}" ]; then
        echo "Fclones RPM (${FCLONES_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        FCLONES_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/fclones-${FCLONES_VERSION}"
        if [ ! -d "${FCLONES_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${FCLONES_VERSION}" https://github.com/pkolaczk/fclones.git "${FCLONES_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/fclones-${FCLONES_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "fclones-${FCLONES_VERSION}"
        cp /build/salt/specs/fclones.spec "${SPECS_DIR}/fclones.spec"

        echo "--- Building Fclones RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/fclones.spec"

        echo "--- Copying Fclones RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "fclones-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Grex RPM ---
GREX_RPM_NAME="grex-${GREX_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "grex" ]]; then
    echo "--- Preparing Grex ---"
    if [ -f "/build/rpms/${GREX_RPM_NAME}" ]; then
        echo "Grex RPM (${GREX_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        GREX_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/grex-${GREX_VERSION}"
        if [ ! -d "${GREX_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${GREX_VERSION}" https://github.com/pemistahl/grex.git "${GREX_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/grex-${GREX_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "grex-${GREX_VERSION}"
        cp /build/salt/specs/grex.spec "${SPECS_DIR}/grex.spec"

        echo "--- Building Grex RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/grex.spec"

        echo "--- Copying Grex RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "grex-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Kmon RPM ---
KMON_RPM_NAME="kmon-${KMON_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "kmon" ]]; then
    echo "--- Preparing Kmon ---"
    if [ -f "/build/rpms/${KMON_RPM_NAME}" ]; then
        echo "Kmon RPM (${KMON_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        KMON_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/kmon-${KMON_VERSION}"
        if [ ! -d "${KMON_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${KMON_VERSION}" https://github.com/orhun/kmon.git "${KMON_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/kmon-${KMON_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "kmon-${KMON_VERSION}"
        cp /build/salt/specs/kmon.spec "${SPECS_DIR}/kmon.spec"

        echo "--- Building Kmon RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/kmon.spec"

        echo "--- Copying Kmon RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "kmon-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Jujutsu RPM ---
JUJUTSU_RPM_NAME="jujutsu-${JUJUTSU_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "jujutsu" ]]; then
    echo "--- Preparing Jujutsu ---"
    if [ -f "/build/rpms/${JUJUTSU_RPM_NAME}" ]; then
        echo "Jujutsu RPM (${JUJUTSU_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo openssl-devel pkgconf-pkg-config cmake

        JUJUTSU_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/jujutsu-${JUJUTSU_VERSION}"
        if [ ! -d "${JUJUTSU_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${JUJUTSU_VERSION}" https://github.com/jj-vcs/jj.git "${JUJUTSU_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/jujutsu-${JUJUTSU_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "jujutsu-${JUJUTSU_VERSION}"
        cp /build/salt/specs/jujutsu.spec "${SPECS_DIR}/jujutsu.spec"

        echo "--- Building Jujutsu RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/jujutsu.spec"

        echo "--- Copying Jujutsu RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "jujutsu-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Zfxtop RPM ---
ZFXTOP_RPM_NAME="zfxtop-${ZFXTOP_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "zfxtop" ]]; then
    echo "--- Preparing Zfxtop ---"
    if [ -f "/build/rpms/${ZFXTOP_RPM_NAME}" ]; then
        echo "Zfxtop RPM (${ZFXTOP_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang

        ZFXTOP_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/zfxtop-${ZFXTOP_VERSION}"
        if [ ! -d "${ZFXTOP_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "${ZFXTOP_VERSION}" https://github.com/ssleert/zfxtop.git "${ZFXTOP_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/zfxtop-${ZFXTOP_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "zfxtop-${ZFXTOP_VERSION}"
        cp /build/salt/specs/zfxtop.spec "${SPECS_DIR}/zfxtop.spec"

        echo "--- Building Zfxtop RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/zfxtop.spec"

        echo "--- Copying Zfxtop RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "zfxtop-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Pup RPM ---
PUP_RPM_NAME="pup-${PUP_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "pup" ]]; then
    echo "--- Preparing Pup ---"
    if [ -f "/build/rpms/${PUP_RPM_NAME}" ]; then
        echo "Pup RPM (${PUP_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang

        PUP_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/pup-${PUP_VERSION}"
        if [ ! -d "${PUP_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${PUP_VERSION}" https://github.com/ericchiang/pup.git "${PUP_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/pup-${PUP_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "pup-${PUP_VERSION}"
        cp /build/salt/specs/pup.spec "${SPECS_DIR}/pup.spec"

        echo "--- Building Pup RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/pup.spec"

        echo "--- Copying Pup RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "pup-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Scc RPM ---
SCC_RPM_NAME="scc-${SCC_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "scc" ]]; then
    echo "--- Preparing Scc ---"
    if [ -f "/build/rpms/${SCC_RPM_NAME}" ]; then
        echo "Scc RPM (${SCC_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang

        SCC_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/scc-${SCC_VERSION}"
        if [ ! -d "${SCC_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${SCC_VERSION}" https://github.com/boyter/scc.git "${SCC_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/scc-${SCC_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "scc-${SCC_VERSION}"
        cp /build/salt/specs/scc.spec "${SPECS_DIR}/scc.spec"

        echo "--- Building Scc RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/scc.spec"

        echo "--- Copying Scc RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "scc-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Ctop RPM ---
CTOP_RPM_NAME="ctop-${CTOP_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "ctop" ]]; then
    echo "--- Preparing Ctop ---"
    if [ -f "/build/rpms/${CTOP_RPM_NAME}" ]; then
        echo "Ctop RPM (${CTOP_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang

        CTOP_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/ctop-${CTOP_VERSION}"
        if [ ! -d "${CTOP_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${CTOP_VERSION}" https://github.com/bcicen/ctop.git "${CTOP_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/ctop-${CTOP_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "ctop-${CTOP_VERSION}"
        cp /build/salt/specs/ctop.spec "${SPECS_DIR}/ctop.spec"

        echo "--- Building Ctop RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/ctop.spec"

        echo "--- Copying Ctop RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "ctop-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Dive RPM ---
DIVE_RPM_NAME="dive-${DIVE_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "dive" ]]; then
    echo "--- Preparing Dive ---"
    if [ -f "/build/rpms/${DIVE_RPM_NAME}" ]; then
        echo "Dive RPM (${DIVE_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang

        DIVE_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/dive-${DIVE_VERSION}"
        if [ ! -d "${DIVE_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${DIVE_VERSION}" https://github.com/wagoodman/dive.git "${DIVE_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/dive-${DIVE_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "dive-${DIVE_VERSION}"
        cp /build/salt/specs/dive.spec "${SPECS_DIR}/dive.spec"

        echo "--- Building Dive RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/dive.spec"

        echo "--- Copying Dive RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "dive-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Zk RPM ---
ZK_RPM_NAME="zk-${ZK_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "zk" ]]; then
    echo "--- Preparing Zk ---"
    if [ -f "/build/rpms/${ZK_RPM_NAME}" ]; then
        echo "Zk RPM (${ZK_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang gcc

        ZK_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/zk-${ZK_VERSION}"
        if [ ! -d "${ZK_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${ZK_VERSION}" https://github.com/zk-org/zk.git "${ZK_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/zk-${ZK_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "zk-${ZK_VERSION}"
        cp /build/salt/specs/zk.spec "${SPECS_DIR}/zk.spec"

        echo "--- Building Zk RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/zk.spec"

        echo "--- Copying Zk RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "zk-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build git-filter-repo RPM ---
GIT_FILTER_REPO_RPM_NAME="git-filter-repo-${GIT_FILTER_REPO_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "git-filter-repo" ]]; then
    echo "--- Preparing git-filter-repo ---"
    if [ -f "/build/rpms/${GIT_FILTER_REPO_RPM_NAME}" ]; then
        echo "git-filter-repo RPM (${GIT_FILTER_REPO_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar

        GFR_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/git-filter-repo-${GIT_FILTER_REPO_VERSION}"
        if [ ! -d "${GFR_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${GIT_FILTER_REPO_VERSION}" https://github.com/newren/git-filter-repo.git "${GFR_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/git-filter-repo-${GIT_FILTER_REPO_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "git-filter-repo-${GIT_FILTER_REPO_VERSION}"
        cp /build/salt/specs/git-filter-repo.spec "${SPECS_DIR}/git-filter-repo.spec"

        echo "--- Building git-filter-repo RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/git-filter-repo.spec"

        echo "--- Copying git-filter-repo RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "git-filter-repo-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Epr RPM ---
EPR_RPM_NAME="epr-${EPR_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "epr" ]]; then
    echo "--- Preparing Epr ---"
    if [ -f "/build/rpms/${EPR_RPM_NAME}" ]; then
        echo "Epr RPM (${EPR_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar

        EPR_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/epr-${EPR_VERSION}"
        if [ ! -d "${EPR_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${EPR_VERSION}" https://github.com/wustho/epr.git "${EPR_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/epr-${EPR_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "epr-${EPR_VERSION}"
        cp /build/salt/specs/epr.spec "${SPECS_DIR}/epr.spec"

        echo "--- Building Epr RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/epr.spec"

        echo "--- Copying Epr RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "epr-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Lutgen RPM ---
LUTGEN_RPM_NAME="lutgen-${LUTGEN_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "lutgen" ]]; then
    echo "--- Preparing Lutgen ---"
    if [ -f "/build/rpms/${LUTGEN_RPM_NAME}" ]; then
        echo "Lutgen RPM (${LUTGEN_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo

        LUTGEN_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/lutgen-${LUTGEN_VERSION}"
        if [ ! -d "${LUTGEN_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${LUTGEN_VERSION}" https://github.com/ozwaldorf/lutgen-rs.git "${LUTGEN_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/lutgen-${LUTGEN_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "lutgen-${LUTGEN_VERSION}"
        cp /build/salt/specs/lutgen.spec "${SPECS_DIR}/lutgen.spec"

        echo "--- Building Lutgen RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/lutgen.spec"

        echo "--- Copying Lutgen RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "lutgen-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Taplo RPM ---
TAPLO_RPM_NAME="taplo-${TAPLO_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "taplo" ]]; then
    echo "--- Preparing Taplo ---"
    if [ -f "/build/rpms/${TAPLO_RPM_NAME}" ]; then
        echo "Taplo RPM (${TAPLO_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo openssl-devel pkgconf-pkg-config

        TAPLO_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/taplo-${TAPLO_VERSION}"
        if [ ! -d "${TAPLO_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "${TAPLO_VERSION}" https://github.com/tamasfe/taplo.git "${TAPLO_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/taplo-${TAPLO_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "taplo-${TAPLO_VERSION}"
        cp /build/salt/specs/taplo.spec "${SPECS_DIR}/taplo.spec"

        echo "--- Building Taplo RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/taplo.spec"

        echo "--- Copying Taplo RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "taplo-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Gist RPM ---
GIST_RPM_NAME="gist-${GIST_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "gist" ]]; then
    echo "--- Preparing Gist ---"
    if [ -f "/build/rpms/${GIST_RPM_NAME}" ]; then
        echo "Gist RPM (${GIST_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar ruby rubygem-rake

        GIST_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/gist-${GIST_VERSION}"
        if [ ! -d "${GIST_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${GIST_VERSION}" https://github.com/defunkt/gist.git "${GIST_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/gist-${GIST_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "gist-${GIST_VERSION}"
        cp /build/salt/specs/gist.spec "${SPECS_DIR}/gist.spec"

        echo "--- Building Gist RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/gist.spec"

        echo "--- Copying Gist RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "gist-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Xxh RPM ---
XXH_RPM_NAME="xxh-${XXH_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "xxh" ]]; then
    echo "--- Preparing Xxh ---"
    if [ -f "/build/rpms/${XXH_RPM_NAME}" ]; then
        echo "Xxh RPM (${XXH_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel

        XXH_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/xxh-${XXH_VERSION}"
        if [ ! -d "${XXH_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "${XXH_VERSION}" https://github.com/xxh/xxh.git "${XXH_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/xxh-${XXH_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "xxh-${XXH_VERSION}"
        cp /build/salt/specs/xxh.spec "${SPECS_DIR}/xxh.spec"

        echo "--- Building Xxh RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/xxh.spec"

        echo "--- Copying Xxh RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "xxh-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Nerdctl RPM ---
NERDCTL_RPM_NAME="nerdctl-${NERDCTL_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "nerdctl" ]]; then
    echo "--- Preparing Nerdctl ---"
    if [ -f "/build/rpms/${NERDCTL_RPM_NAME}" ]; then
        echo "Nerdctl RPM (${NERDCTL_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang

        NERDCTL_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/nerdctl-${NERDCTL_VERSION}"
        if [ ! -d "${NERDCTL_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${NERDCTL_VERSION}" https://github.com/containerd/nerdctl.git "${NERDCTL_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/nerdctl-${NERDCTL_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "nerdctl-${NERDCTL_VERSION}"
        cp /build/salt/specs/nerdctl.spec "${SPECS_DIR}/nerdctl.spec"

        echo "--- Building Nerdctl RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/nerdctl.spec"

        echo "--- Copying Nerdctl RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "nerdctl-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Rapidgzip RPM ---
RAPIDGZIP_RPM_NAME="rapidgzip-${RAPIDGZIP_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "rapidgzip" ]]; then
    echo "--- Preparing Rapidgzip ---"
    if [ -f "/build/rpms/${RAPIDGZIP_RPM_NAME}" ]; then
        echo "Rapidgzip RPM (${RAPIDGZIP_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel gcc-c++ nasm

        RAPIDGZIP_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/rapidgzip-${RAPIDGZIP_VERSION}"
        if [ ! -d "${RAPIDGZIP_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --recursive --branch "rapidgzip-v${RAPIDGZIP_VERSION}" https://github.com/mxmlnkn/rapidgzip.git "${RAPIDGZIP_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/rapidgzip-${RAPIDGZIP_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "rapidgzip-${RAPIDGZIP_VERSION}"
        cp /build/salt/specs/rapidgzip.spec "${SPECS_DIR}/rapidgzip.spec"

        echo "--- Building Rapidgzip RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/rapidgzip.spec"

        echo "--- Copying Rapidgzip RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "rapidgzip-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Scour RPM ---
SCOUR_RPM_NAME="scour-${SCOUR_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "scour" ]]; then
    echo "--- Preparing Scour ---"
    if [ -f "/build/rpms/${SCOUR_RPM_NAME}" ]; then
        echo "Scour RPM (${SCOUR_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar python3-devel

        SCOUR_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/scour-${SCOUR_VERSION}"
        if [ ! -d "${SCOUR_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${SCOUR_VERSION}" https://github.com/scour-project/scour.git "${SCOUR_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/scour-${SCOUR_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "scour-${SCOUR_VERSION}"
        cp /build/salt/specs/scour.spec "${SPECS_DIR}/scour.spec"

        echo "--- Building Scour RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/scour.spec"

        echo "--- Copying Scour RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "scour-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Iosevka RPM ---
IOSEVKA_RPM_NAME="iosevka-neg-fonts-${IOSEVKA_VERSION}-2.fc43.noarch.rpm"
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

# --- Build Bandwhich RPM ---
BANDWHICH_RPM_NAME="bandwhich-${BANDWHICH_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "bandwhich" ]]; then
    echo "--- Preparing Bandwhich ---"
    if [ -f "/build/rpms/${BANDWHICH_RPM_NAME}" ]; then
        echo "Bandwhich RPM (${BANDWHICH_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo
        BANDWHICH_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/bandwhich-${BANDWHICH_VERSION}"
        if [ ! -d "${BANDWHICH_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${BANDWHICH_VERSION}" https://github.com/imsnif/bandwhich.git "${BANDWHICH_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/bandwhich-${BANDWHICH_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "bandwhich-${BANDWHICH_VERSION}"
        cp /build/salt/specs/bandwhich.spec "${SPECS_DIR}/bandwhich.spec"
        echo "--- Building Bandwhich RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/bandwhich.spec"
        echo "--- Copying Bandwhich RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "bandwhich-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Xh RPM ---
XH_RPM_NAME="xh-${XH_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "xh" ]]; then
    echo "--- Preparing Xh ---"
    if [ -f "/build/rpms/${XH_RPM_NAME}" ]; then
        echo "Xh RPM (${XH_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo
        XH_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/xh-${XH_VERSION}"
        if [ ! -d "${XH_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${XH_VERSION}" https://github.com/ducaale/xh.git "${XH_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/xh-${XH_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "xh-${XH_VERSION}"
        cp /build/salt/specs/xh.spec "${SPECS_DIR}/xh.spec"
        echo "--- Building Xh RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/xh.spec"
        echo "--- Copying Xh RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "xh-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Curlie RPM ---
CURLIE_RPM_NAME="curlie-${CURLIE_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "curlie" ]]; then
    echo "--- Preparing Curlie ---"
    if [ -f "/build/rpms/${CURLIE_RPM_NAME}" ]; then
        echo "Curlie RPM (${CURLIE_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang
        CURLIE_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/curlie-${CURLIE_VERSION}"
        if [ ! -d "${CURLIE_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${CURLIE_VERSION}" https://github.com/rs/curlie.git "${CURLIE_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/curlie-${CURLIE_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "curlie-${CURLIE_VERSION}"
        cp /build/salt/specs/curlie.spec "${SPECS_DIR}/curlie.spec"
        echo "--- Building Curlie RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/curlie.spec"
        echo "--- Copying Curlie RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "curlie-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Doggo RPM ---
DOGGO_RPM_NAME="doggo-${DOGGO_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "doggo" ]]; then
    echo "--- Preparing Doggo ---"
    if [ -f "/build/rpms/${DOGGO_RPM_NAME}" ]; then
        echo "Doggo RPM (${DOGGO_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang
        DOGGO_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/doggo-${DOGGO_VERSION}"
        if [ ! -d "${DOGGO_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${DOGGO_VERSION}" https://github.com/mr-karan/doggo.git "${DOGGO_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/doggo-${DOGGO_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "doggo-${DOGGO_VERSION}"
        cp /build/salt/specs/doggo.spec "${SPECS_DIR}/doggo.spec"
        echo "--- Building Doggo RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/doggo.spec"
        echo "--- Copying Doggo RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "doggo-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Carapace RPM ---
CARAPACE_RPM_NAME="carapace-${CARAPACE_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "carapace" ]]; then
    echo "--- Preparing Carapace ---"
    if [ -f "/build/rpms/${CARAPACE_RPM_NAME}" ]; then
        echo "Carapace RPM (${CARAPACE_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar golang
        CARAPACE_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/carapace-${CARAPACE_VERSION}"
        if [ ! -d "${CARAPACE_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${CARAPACE_VERSION}" https://github.com/carapace-sh/carapace-bin.git "${CARAPACE_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/carapace-${CARAPACE_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "carapace-${CARAPACE_VERSION}"
        cp /build/salt/specs/carapace.spec "${SPECS_DIR}/carapace.spec"
        echo "--- Building Carapace RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/carapace.spec"
        echo "--- Copying Carapace RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "carapace-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Wallust RPM ---
WALLUST_RPM_NAME="wallust-${WALLUST_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "wallust" ]]; then
    echo "--- Preparing Wallust ---"
    if [ -f "/build/rpms/${WALLUST_RPM_NAME}" ]; then
        echo "Wallust RPM (${WALLUST_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo
        WALLUST_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/wallust-${WALLUST_VERSION}"
        if [ ! -d "${WALLUST_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "${WALLUST_VERSION}" https://codeberg.org/explosion-mental/wallust.git "${WALLUST_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/wallust-${WALLUST_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "wallust-${WALLUST_VERSION}"
        cp /build/salt/specs/wallust.spec "${SPECS_DIR}/wallust.spec"
        echo "--- Building Wallust RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/wallust.spec"
        echo "--- Copying Wallust RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "wallust-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build wl-clip-persist RPM ---
WL_CLIP_PERSIST_RPM_NAME="wl-clip-persist-${WL_CLIP_PERSIST_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "wl-clip-persist" ]]; then
    echo "--- Preparing wl-clip-persist ---"
    if [ -f "/build/rpms/${WL_CLIP_PERSIST_RPM_NAME}" ]; then
        echo "wl-clip-persist RPM (${WL_CLIP_PERSIST_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo
        WL_CLIP_PERSIST_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/wl-clip-persist-${WL_CLIP_PERSIST_VERSION}"
        if [ ! -d "${WL_CLIP_PERSIST_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${WL_CLIP_PERSIST_VERSION}" https://github.com/Linus789/wl-clip-persist.git "${WL_CLIP_PERSIST_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/wl-clip-persist-${WL_CLIP_PERSIST_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "wl-clip-persist-${WL_CLIP_PERSIST_VERSION}"
        cp /build/salt/specs/wl-clip-persist.spec "${SPECS_DIR}/wl-clip-persist.spec"
        echo "--- Building wl-clip-persist RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/wl-clip-persist.spec"
        echo "--- Copying wl-clip-persist RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "wl-clip-persist-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Quickshell RPM ---
QUICKSHELL_RPM_NAME="quickshell-${QUICKSHELL_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "quickshell" ]]; then
    echo "--- Preparing Quickshell ---"
    if [ -f "/build/rpms/${QUICKSHELL_RPM_NAME}" ]; then
        echo "Quickshell RPM (${QUICKSHELL_RPM_NAME}) already exists, skipping."
    else
        # Install Qt6 packages from base repo only (without updates) to match
        # the host's Wayblue base image Qt version (6.9.x, not 6.10.x)
        dnf install -y --skip-unavailable --disablerepo=updates git rpm-build tar cmake ninja-build gcc-c++ \
            qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
            qt6-qtshadertools-devel qt6-qtwayland-devel \
            qt6-qtsvg-devel spirv-tools cli11-devel jemalloc-devel \
            wayland-devel wayland-protocols-devel \
            libdrm-devel mesa-libgbm-devel mesa-libEGL-devel \
            pipewire-devel pam-devel \
            polkit-devel glib2-devel \
            libxcb-devel xcb-util-devel
        QUICKSHELL_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/quickshell-${QUICKSHELL_VERSION}"
        if [ ! -d "${QUICKSHELL_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${QUICKSHELL_VERSION}" https://github.com/quickshell-mirror/quickshell.git "${QUICKSHELL_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/quickshell-${QUICKSHELL_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "quickshell-${QUICKSHELL_VERSION}"
        cp /build/salt/specs/quickshell.spec "${SPECS_DIR}/quickshell.spec"
        echo "--- Building Quickshell RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/quickshell.spec"
        echo "--- Copying Quickshell RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "quickshell-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build SwayOSD RPM ---
SWAYOSD_RPM_NAME="swayosd-${SWAYOSD_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "swayosd" ]]; then
    echo "--- Preparing SwayOSD ---"
    if [ -f "/build/rpms/${SWAYOSD_RPM_NAME}" ]; then
        echo "SwayOSD RPM (${SWAYOSD_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar rust cargo meson ninja-build pkgconf-pkg-config glib2-devel sassc gtk4-devel gtk4-layer-shell-devel pulseaudio-libs-devel libinput-devel libevdev-devel systemd-devel dbus-devel
        SWAYOSD_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/swayosd-${SWAYOSD_VERSION}"
        if [ ! -d "${SWAYOSD_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${SWAYOSD_VERSION}" https://github.com/ErikReider/SwayOSD.git "${SWAYOSD_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/swayosd-${SWAYOSD_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "swayosd-${SWAYOSD_VERSION}"
        cp /build/salt/specs/swayosd.spec "${SPECS_DIR}/swayosd.spec"
        echo "--- Building SwayOSD RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/swayosd.spec"
        echo "--- Copying SwayOSD RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "swayosd-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build xdg-desktop-portal-termfilechooser RPM ---
XDG_TERMFILECHOOSER_RPM_NAME="xdg-desktop-portal-termfilechooser-${XDG_TERMFILECHOOSER_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "xdg-desktop-portal-termfilechooser" ]]; then
    echo "--- Preparing xdg-desktop-portal-termfilechooser ---"
    if [ -f "/build/rpms/${XDG_TERMFILECHOOSER_RPM_NAME}" ]; then
        echo "xdg-desktop-portal-termfilechooser RPM (${XDG_TERMFILECHOOSER_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar gcc meson ninja-build pkgconf-pkg-config inih-devel systemd-devel scdoc
        XDG_TFC_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/xdg-desktop-portal-termfilechooser-${XDG_TERMFILECHOOSER_VERSION}"
        if [ ! -d "${XDG_TFC_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 https://github.com/GermainZ/xdg-desktop-portal-termfilechooser.git "${XDG_TFC_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/xdg-desktop-portal-termfilechooser-${XDG_TERMFILECHOOSER_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "xdg-desktop-portal-termfilechooser-${XDG_TERMFILECHOOSER_VERSION}"
        cp /build/salt/specs/xdg-desktop-portal-termfilechooser.spec "${SPECS_DIR}/xdg-desktop-portal-termfilechooser.spec"
        echo "--- Building xdg-desktop-portal-termfilechooser RPM ---"
        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/xdg-desktop-portal-termfilechooser.spec"
        echo "--- Copying xdg-desktop-portal-termfilechooser RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "xdg-desktop-portal-termfilechooser-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Bucklespring RPM ---
BUCKLESPRING_RPM_NAME="bucklespring-${BUCKLESPRING_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "bucklespring" ]]; then
    echo "--- Preparing Bucklespring ---"
    if [ -f "/build/rpms/${BUCKLESPRING_RPM_NAME}" ]; then
        echo "Bucklespring RPM (${BUCKLESPRING_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar gcc make pkgconf-pkg-config openal-soft-devel alure-devel libX11-devel libXtst-devel

        BUCKLESPRING_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/bucklespring-${BUCKLESPRING_VERSION}"
        if [ ! -d "${BUCKLESPRING_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${BUCKLESPRING_VERSION}" https://github.com/zevv/bucklespring.git "${BUCKLESPRING_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/bucklespring-${BUCKLESPRING_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "bucklespring-${BUCKLESPRING_VERSION}"
        cp /build/salt/specs/bucklespring.spec "${SPECS_DIR}/bucklespring.spec"

        echo "--- Building Bucklespring RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/bucklespring.spec"

        echo "--- Copying Bucklespring RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "bucklespring-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Taoup RPM ---
TAOUP_RPM_NAME="taoup-${TAOUP_VERSION}-1.fc43.noarch.rpm"
if [[ $# -eq 0 || "$1" == "taoup" ]]; then
    echo "--- Preparing Taoup ---"
    if [ -f "/build/rpms/${TAOUP_RPM_NAME}" ]; then
        echo "Taoup RPM (${TAOUP_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar ruby

        TAOUP_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/taoup-${TAOUP_VERSION}"
        if [ ! -d "${TAOUP_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "v${TAOUP_VERSION}" https://github.com/globalcitizen/taoup.git "${TAOUP_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/taoup-${TAOUP_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "taoup-${TAOUP_VERSION}"
        cp /build/salt/specs/taoup.spec "${SPECS_DIR}/taoup.spec"

        echo "--- Building Taoup RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/taoup.spec"

        echo "--- Copying Taoup RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "taoup-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# --- Build Newsraft RPM ---
NEWSRAFT_RPM_NAME="newsraft-${NEWSRAFT_VERSION}-1.fc43.x86_64.rpm"
if [[ $# -eq 0 || "$1" == "newsraft" ]]; then
    echo "--- Preparing Newsraft ---"
    if [ -f "/build/rpms/${NEWSRAFT_RPM_NAME}" ]; then
        echo "Newsraft RPM (${NEWSRAFT_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken git rpm-build tar gcc make ncurses-devel libcurl-devel yajl-devel gumbo-parser-devel scdoc

        NEWSRAFT_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/newsraft-${NEWSRAFT_VERSION}"
        if [ ! -d "${NEWSRAFT_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 --branch "newsraft-${NEWSRAFT_VERSION}" https://codeberg.org/grstratos/newsraft.git "${NEWSRAFT_SOURCE_DIR}"
        fi
        tar -czf "${SOURCES_DIR}/newsraft-${NEWSRAFT_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "newsraft-${NEWSRAFT_VERSION}"
        cp /build/salt/specs/newsraft.spec "${SPECS_DIR}/newsraft.spec"

        echo "--- Building Newsraft RPM ---"
        rpmbuild \
            --define "_topdir ${RPM_BUILD_ROOT}" \
            -ba "${SPECS_DIR}/newsraft.spec"

        echo "--- Copying Newsraft RPMs to /build/rpms/ ---"
        find "${RPMS_DIR}" -name "newsraft-*.rpm" -exec cp -v {} /build/rpms/ \;
    fi
fi

# Clean up (optional)
# rm -rf "${RPM_BUILD_ROOT}"

echo "All RPMs built and copied to /build/rpms/"
ls -l /build/rpms/
