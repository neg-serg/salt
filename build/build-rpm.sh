#!/bin/bash
set -euo pipefail

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
UNFLAC_VERSION="1.4"
ALBUMDETAILS_VERSION="0.1"
CMAKE_LS_VERSION="0.1.11"
NGINX_LS_VERSION="0.9.0"
SYSTEMD_LS_VERSION="0.3.5"
MASSREN_VERSION="1.5.6"
CROC_VERSION="10.3.1"
FAKER_VERSION="40.4.0"
SPEEDTEST_GO_VERSION="1.7.10"
GREETD_VERSION="0.10.3"
RUSTNET_VERSION="1.0.0"

# RPM build root directory inside the container
RPM_BUILD_ROOT="/rpmbuild"
SOURCES_DIR="${RPM_BUILD_ROOT}/SOURCES"
SPECS_DIR="${RPM_BUILD_ROOT}/SPECS"
RPMS_DIR="${RPM_BUILD_ROOT}/RPMS"
SRPMS_DIR="${RPM_BUILD_ROOT}/SRPMS"

# Create RPM build directories
mkdir -p "$SOURCES_DIR" "$SPECS_DIR" "$RPMS_DIR" "$SRPMS_DIR"

# Build a package from git source: clone → tar → rpmbuild
# Positional args: name version url deps
# Options:
#   --ref REF              git branch/tag to clone
#   --arch ARCH            RPM arch (default: x86_64)
#   --recursive            git clone --recursive
#   --source-dir DIR       override source dir name (default: name-version)
#   --dnf-flags FLAGS      override dnf flags (default: "--skip-broken")
#   --extra-sources FILES  space-separated files to copy to SOURCES
build_pkg() {
    local name="$1" version="$2" url="$3" deps="$4"
    shift 4

    local ref="" arch="x86_64" source_dir="" dnf_flags="--skip-broken" extra_sources=""
    local -a clone_extra=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ref) ref="$2"; shift 2 ;;
            --arch) arch="$2"; shift 2 ;;
            --recursive) clone_extra+=(--recursive); shift ;;
            --source-dir) source_dir="$2"; shift 2 ;;
            --dnf-flags) dnf_flags="$2"; shift 2 ;;
            --extra-sources) extra_sources="$2"; shift 2 ;;
            *) echo "build_pkg: unknown option: $1" >&2; return 1 ;;
        esac
    done

    source_dir="${source_dir:-${name}-${version}}"
    local rpm_file="${name}-${version}-1.fc43.${arch}.rpm"

    if [ -f "/build/rpms/${rpm_file}" ]; then
        echo "${name} RPM (${rpm_file}) already exists, skipping."
        return 0
    fi

    # shellcheck disable=SC2086
    dnf install -y ${dnf_flags} ${deps}

    local src="${RPM_BUILD_ROOT}/BUILD/${source_dir}"
    if [ ! -d "${src}" ]; then
        mkdir -p "${RPM_BUILD_ROOT}/BUILD"
        git clone --depth 1 "${clone_extra[@]}" ${ref:+--branch "$ref"} "${url}" "${src}"
    fi

    tar -czf "${SOURCES_DIR}/${source_dir}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "${source_dir}"

    if [[ -n "${extra_sources}" ]]; then
        # shellcheck disable=SC2086
        for f in ${extra_sources}; do
            cp "${f}" "${SOURCES_DIR}/"
        done
    fi

    cp "/build/salt/specs/${name}.spec" "${SPECS_DIR}/${name}.spec"
    rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/${name}.spec"
    find "${RPMS_DIR}" -name "${name}-*.rpm" -exec cp {} /build/rpms/ \;
}

# All packages in build order
ALL_PACKAGES=(
    duf massren raise pipemixer richcolors neg-pretty-printer
    choose ouch htmlq erdtree viu fclones grex kmon jujutsu
    zfxtop pup scc ctop dive zk git-filter-repo epr lutgen taplo
    gist xxh nerdctl rapidgzip scour iosevka bandwhich xh curlie
    doggo carapace wallust wl-clip-persist quickshell swayosd
    xdg-desktop-portal-termfilechooser bucklespring taoup
    newsraft unflac albumdetails cmake-language-server
    nginx-language-server systemd-language-server croc faker
    speedtest-go greetd rustnet
)

# Build all packages when called with no arguments
if [[ $# -eq 0 ]]; then
    for pkg in "${ALL_PACKAGES[@]}"; do
        "$0" "$pkg"
    done
    echo "All RPMs built and copied to /build/rpms/"
    ls -l /build/rpms/
    exit 0
fi

case "$1" in
duf)
    build_pkg duf "$DUF_VERSION" \
        "https://github.com/neg-serg/duf.git" \
        "git rpm-build tar golang"
    ;;
massren)
    build_pkg massren "$MASSREN_VERSION" \
        "https://github.com/laurent22/massren.git" \
        "git rpm-build tar golang"
    ;;
raise)
    build_pkg raise "$RAISE_VERSION" \
        "https://github.com/neg-serg/raise.git" \
        "git rpm-build tar rust cargo"
    ;;
pipemixer)
    build_pkg pipemixer "$PIPEMIXER_VERSION" \
        "https://github.com/heather7283/pipemixer.git" \
        "git rpm-build tar gcc meson ninja-build pkgconf-pkg-config pipewire-devel ncurses-devel inih-devel" \
        --ref "v${PIPEMIXER_VERSION}"
    ;;
richcolors)
    build_pkg richcolors "$RICHCOLORS_VERSION" \
        "https://github.com/Rizen54/richcolors.git" \
        "git rpm-build tar" \
        --arch noarch
    ;;
neg-pretty-printer)
    # Custom: copies from local dir instead of git clone
    NEG_PRETTY_PRINTER_RPM_NAME="neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}-1.fc43.noarch.rpm"
    if [ -f "/build/rpms/${NEG_PRETTY_PRINTER_RPM_NAME}" ]; then
        echo "neg-pretty-printer RPM (${NEG_PRETTY_PRINTER_RPM_NAME}) already exists, skipping."
    else
        dnf install -y --skip-broken rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel

        NEG_PP_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}"
        if [ ! -d "${NEG_PP_SOURCE_DIR}" ]; then
            mkdir -p "${NEG_PP_SOURCE_DIR}"
            cp -r /build/pretty-printer/* /build/pretty-printer/.gitignore "${NEG_PP_SOURCE_DIR}/" 2>/dev/null || true
        fi
        tar -czf "${SOURCES_DIR}/neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "neg-pretty-printer-${NEG_PRETTY_PRINTER_VERSION}"
        cp /build/salt/specs/neg-pretty-printer.spec "${SPECS_DIR}/neg-pretty-printer.spec"

        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/neg-pretty-printer.spec"

        find "${RPMS_DIR}" -name "neg-pretty-printer-*.rpm" -exec cp {} /build/rpms/ \;
    fi
    ;;
choose)
    build_pkg choose "$CHOOSE_VERSION" \
        "https://github.com/theryangeary/choose.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${CHOOSE_VERSION}"
    ;;
ouch)
    build_pkg ouch "$OUCH_VERSION" \
        "https://github.com/ouch-org/ouch.git" \
        "git rpm-build tar rust cargo gcc-c++ clang clang-devel" \
        --ref "${OUCH_VERSION}"
    ;;
htmlq)
    build_pkg htmlq "$HTMLQ_VERSION" \
        "https://github.com/mgdm/htmlq.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${HTMLQ_VERSION}"
    ;;
erdtree)
    build_pkg erdtree "$ERDTREE_VERSION" \
        "https://github.com/solidiquis/erdtree.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${ERDTREE_VERSION}"
    ;;
viu)
    build_pkg viu "$VIU_VERSION" \
        "https://github.com/atanunq/viu.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${VIU_VERSION}"
    ;;
fclones)
    build_pkg fclones "$FCLONES_VERSION" \
        "https://github.com/pkolaczk/fclones.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${FCLONES_VERSION}"
    ;;
grex)
    build_pkg grex "$GREX_VERSION" \
        "https://github.com/pemistahl/grex.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${GREX_VERSION}"
    ;;
kmon)
    build_pkg kmon "$KMON_VERSION" \
        "https://github.com/orhun/kmon.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${KMON_VERSION}"
    ;;
jujutsu)
    build_pkg jujutsu "$JUJUTSU_VERSION" \
        "https://github.com/jj-vcs/jj.git" \
        "git rpm-build tar rust cargo openssl-devel pkgconf-pkg-config cmake" \
        --ref "v${JUJUTSU_VERSION}"
    ;;
zfxtop)
    build_pkg zfxtop "$ZFXTOP_VERSION" \
        "https://github.com/ssleert/zfxtop.git" \
        "git rpm-build tar golang" \
        --ref "${ZFXTOP_VERSION}"
    ;;
pup)
    build_pkg pup "$PUP_VERSION" \
        "https://github.com/ericchiang/pup.git" \
        "git rpm-build tar golang" \
        --ref "v${PUP_VERSION}"
    ;;
scc)
    build_pkg scc "$SCC_VERSION" \
        "https://github.com/boyter/scc.git" \
        "git rpm-build tar golang" \
        --ref "v${SCC_VERSION}"
    ;;
ctop)
    build_pkg ctop "$CTOP_VERSION" \
        "https://github.com/bcicen/ctop.git" \
        "git rpm-build tar golang" \
        --ref "v${CTOP_VERSION}"
    ;;
dive)
    build_pkg dive "$DIVE_VERSION" \
        "https://github.com/wagoodman/dive.git" \
        "git rpm-build tar golang" \
        --ref "v${DIVE_VERSION}"
    ;;
zk)
    build_pkg zk "$ZK_VERSION" \
        "https://github.com/zk-org/zk.git" \
        "git rpm-build tar golang gcc" \
        --ref "v${ZK_VERSION}"
    ;;
git-filter-repo)
    build_pkg git-filter-repo "$GIT_FILTER_REPO_VERSION" \
        "https://github.com/newren/git-filter-repo.git" \
        "git rpm-build tar" \
        --ref "v${GIT_FILTER_REPO_VERSION}" --arch noarch
    ;;
epr)
    build_pkg epr "$EPR_VERSION" \
        "https://github.com/wustho/epr.git" \
        "git rpm-build tar" \
        --ref "v${EPR_VERSION}" --arch noarch
    ;;
lutgen)
    build_pkg lutgen "$LUTGEN_VERSION" \
        "https://github.com/ozwaldorf/lutgen-rs.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${LUTGEN_VERSION}"
    ;;
taplo)
    build_pkg taplo "$TAPLO_VERSION" \
        "https://github.com/tamasfe/taplo.git" \
        "git rpm-build tar rust cargo openssl-devel pkgconf-pkg-config" \
        --ref "${TAPLO_VERSION}"
    ;;
gist)
    build_pkg gist "$GIST_VERSION" \
        "https://github.com/defunkt/gist.git" \
        "git rpm-build tar ruby rubygem-rake" \
        --ref "v${GIST_VERSION}" --arch noarch
    ;;
xxh)
    build_pkg xxh "$XXH_VERSION" \
        "https://github.com/xxh/xxh.git" \
        "git rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel" \
        --ref "${XXH_VERSION}" --arch noarch
    ;;
nerdctl)
    build_pkg nerdctl "$NERDCTL_VERSION" \
        "https://github.com/containerd/nerdctl.git" \
        "git rpm-build tar golang" \
        --ref "v${NERDCTL_VERSION}"
    ;;
rapidgzip)
    build_pkg rapidgzip "$RAPIDGZIP_VERSION" \
        "https://github.com/mxmlnkn/rapidgzip.git" \
        "git rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel gcc-c++ nasm" \
        --ref "rapidgzip-v${RAPIDGZIP_VERSION}" --recursive
    ;;
scour)
    build_pkg scour "$SCOUR_VERSION" \
        "https://github.com/scour-project/scour.git" \
        "git rpm-build tar python3-devel" \
        --ref "v${SCOUR_VERSION}" --arch noarch
    ;;
iosevka)
    # Custom: different source dir naming, git checkout, extra source file, different spec name
    IOSEVKA_RPM_NAME="iosevka-neg-fonts-${IOSEVKA_VERSION}-2.fc43.noarch.rpm"
    if [ -f "/build/rpms/${IOSEVKA_RPM_NAME}" ]; then
        echo "Iosevka RPM (${IOSEVKA_RPM_NAME}) already exists, skipping."
    else
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

        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/iosevka-neg-fonts.spec"

        find "${RPMS_DIR}" -name "iosevka-neg-fonts-*.rpm" -exec cp {} /build/rpms/ \;
    fi
    ;;
bandwhich)
    build_pkg bandwhich "$BANDWHICH_VERSION" \
        "https://github.com/imsnif/bandwhich.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${BANDWHICH_VERSION}"
    ;;
xh)
    build_pkg xh "$XH_VERSION" \
        "https://github.com/ducaale/xh.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${XH_VERSION}"
    ;;
curlie)
    build_pkg curlie "$CURLIE_VERSION" \
        "https://github.com/rs/curlie.git" \
        "git rpm-build tar golang" \
        --ref "v${CURLIE_VERSION}"
    ;;
doggo)
    build_pkg doggo "$DOGGO_VERSION" \
        "https://github.com/mr-karan/doggo.git" \
        "git rpm-build tar golang" \
        --ref "v${DOGGO_VERSION}"
    ;;
carapace)
    build_pkg carapace "$CARAPACE_VERSION" \
        "https://github.com/carapace-sh/carapace-bin.git" \
        "git rpm-build tar golang" \
        --ref "v${CARAPACE_VERSION}"
    ;;
wallust)
    build_pkg wallust "$WALLUST_VERSION" \
        "https://codeberg.org/explosion-mental/wallust.git" \
        "git rpm-build tar rust cargo" \
        --ref "${WALLUST_VERSION}"
    ;;
wl-clip-persist)
    build_pkg wl-clip-persist "$WL_CLIP_PERSIST_VERSION" \
        "https://github.com/Linus789/wl-clip-persist.git" \
        "git rpm-build tar rust cargo" \
        --ref "v${WL_CLIP_PERSIST_VERSION}"
    ;;
quickshell)
    build_pkg quickshell "$QUICKSHELL_VERSION" \
        "https://github.com/quickshell-mirror/quickshell.git" \
        "git rpm-build tar cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtshadertools-devel qt6-qtwayland-devel qt6-qtsvg-devel spirv-tools cli11-devel jemalloc-devel wayland-devel wayland-protocols-devel libdrm-devel mesa-libgbm-devel mesa-libEGL-devel pipewire-devel pam-devel polkit-devel glib2-devel libxcb-devel xcb-util-devel" \
        --ref "v${QUICKSHELL_VERSION}" \
        --dnf-flags "--skip-unavailable --disablerepo=updates"
    ;;
swayosd)
    build_pkg swayosd "$SWAYOSD_VERSION" \
        "https://github.com/ErikReider/SwayOSD.git" \
        "git rpm-build tar rust cargo meson ninja-build pkgconf-pkg-config glib2-devel sassc gtk4-devel gtk4-layer-shell-devel pulseaudio-libs-devel libinput-devel libevdev-devel systemd-devel dbus-devel" \
        --ref "v${SWAYOSD_VERSION}"
    ;;
xdg-desktop-portal-termfilechooser)
    build_pkg xdg-desktop-portal-termfilechooser "$XDG_TERMFILECHOOSER_VERSION" \
        "https://github.com/GermainZ/xdg-desktop-portal-termfilechooser.git" \
        "git rpm-build tar gcc meson ninja-build pkgconf-pkg-config inih-devel systemd-devel scdoc"
    ;;
bucklespring)
    build_pkg bucklespring "$BUCKLESPRING_VERSION" \
        "https://github.com/zevv/bucklespring.git" \
        "git rpm-build tar gcc make pkgconf-pkg-config openal-soft-devel alure-devel libX11-devel libXtst-devel" \
        --ref "v${BUCKLESPRING_VERSION}"
    ;;
taoup)
    build_pkg taoup "$TAOUP_VERSION" \
        "https://github.com/globalcitizen/taoup.git" \
        "git rpm-build tar ruby" \
        --ref "v${TAOUP_VERSION}" --arch noarch
    ;;
newsraft)
    build_pkg newsraft "$NEWSRAFT_VERSION" \
        "https://codeberg.org/newsraft/newsraft.git" \
        "git rpm-build tar gcc make ncurses-devel libcurl-devel yajl-devel gumbo-parser-devel sqlite-devel expat-devel scdoc" \
        --ref "newsraft-${NEWSRAFT_VERSION}"
    ;;
unflac)
    build_pkg unflac "$UNFLAC_VERSION" \
        "https://git.sr.ht/~ft/unflac" \
        "git rpm-build tar golang" \
        --ref "${UNFLAC_VERSION}"
    ;;
albumdetails)
    build_pkg albumdetails "$ALBUMDETAILS_VERSION" \
        "https://github.com/neg-serg/albumdetails.git" \
        "git rpm-build tar gcc make taglib-devel" \
        --source-dir "albumdetails-master"
    ;;
cmake-language-server)
    build_pkg cmake-language-server "$CMAKE_LS_VERSION" \
        "https://github.com/regen100/cmake-language-server.git" \
        "git rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel" \
        --ref "v${CMAKE_LS_VERSION}" --arch noarch
    ;;
nginx-language-server)
    build_pkg nginx-language-server "$NGINX_LS_VERSION" \
        "https://github.com/pappasam/nginx-language-server.git" \
        "git rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel" \
        --ref "v${NGINX_LS_VERSION}"
    ;;
systemd-language-server)
    build_pkg systemd-language-server "$SYSTEMD_LS_VERSION" \
        "https://github.com/psacawa/systemd-language-server.git" \
        "git rpm-build tar gcc python3-devel python3-pip python3-setuptools python3-wheel libxml2-devel libxslt-devel" \
        --ref "${SYSTEMD_LS_VERSION}"
    ;;
croc)
    build_pkg croc "$CROC_VERSION" \
        "https://github.com/schollz/croc.git" \
        "git rpm-build tar golang" \
        --ref "v${CROC_VERSION}"
    ;;
faker)
    build_pkg faker "$FAKER_VERSION" \
        "https://github.com/joke2k/faker.git" \
        "git rpm-build tar python3-devel python3-pip python3-setuptools python3-wheel" \
        --ref "v${FAKER_VERSION}" --arch noarch
    ;;
speedtest-go)
    build_pkg speedtest-go "$SPEEDTEST_GO_VERSION" \
        "https://github.com/showwin/speedtest-go.git" \
        "git rpm-build tar golang" \
        --ref "v${SPEEDTEST_GO_VERSION}"
    ;;
greetd)
    build_pkg greetd "$GREETD_VERSION" \
        "https://git.sr.ht/~kennylevinsen/greetd" \
        "git rpm-build tar rust cargo scdoc pam-devel selinux-policy-devel systemd systemd-devel systemd-rpm-macros" \
        --ref "${GREETD_VERSION}" \
        --extra-sources "/build/salt/greetd-files/greetd.pam /build/salt/greetd-files/greetd-greeter.pam /build/salt/greetd-files/greetd.sysusers /build/salt/greetd-files/greetd.tmpfiles /build/salt/greetd-files/greetd.fc"
    ;;
rustnet)
    build_pkg rustnet "$RUSTNET_VERSION" \
        "https://github.com/domcyrus/rustnet.git" \
        "git rpm-build tar rust cargo libpcap-devel" \
        --ref "v${RUSTNET_VERSION}"
    ;;
*)
    echo "Unknown package: $1" >&2
    exit 1
    ;;
esac
