#!/bin/bash
set -euo pipefail

# Load versions from shared YAML (single source of truth)
declare -A V
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*#|^[[:space:]]*$ ]] && continue
    key="${line%%:*}"
    value="${line#*: }"
    value="${value//\"/}"
    V["$key"]="$value"
done < "$(dirname "$0")/versions.yaml"

# Common dependency sets
DEPS_BASE="git rpm-build tar"
DEPS_RUST="$DEPS_BASE rust cargo"
DEPS_GO="$DEPS_BASE golang"
DEPS_PYTHON="$DEPS_BASE python3-devel python3-pip python3-setuptools python3-wheel"

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

    local ref="" arch="x86_64" source_dir="" dnf_flags="--skip-broken" extra_sources="" local_source=""
    local -a clone_extra=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ref) ref="$2"; shift 2 ;;
            --arch) arch="$2"; shift 2 ;;
            --recursive) clone_extra+=(--recursive); shift ;;
            --source-dir) source_dir="$2"; shift 2 ;;
            --dnf-flags) dnf_flags="$2"; shift 2 ;;
            --extra-sources) extra_sources="$2"; shift 2 ;;
            --local-source) local_source="$2"; shift 2 ;;
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
        if [[ -n "${local_source}" ]]; then
            mkdir -p "${src}"
            cp -r "${local_source}"/. "${src}/"
        else
            git clone --depth 1 "${clone_extra[@]}" ${ref:+--branch "$ref"} "${url}" "${src}"
        fi
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
    build_pkg duf "${V[duf]}" \
        "https://github.com/neg-serg/duf.git" \
        "$DEPS_GO"
    ;;
massren)
    build_pkg massren "${V[massren]}" \
        "https://github.com/laurent22/massren.git" \
        "$DEPS_GO"
    ;;
raise)
    build_pkg raise "${V[raise]}" \
        "https://github.com/neg-serg/raise.git" \
        "$DEPS_RUST"
    ;;
pipemixer)
    build_pkg pipemixer "${V[pipemixer]}" \
        "https://github.com/heather7283/pipemixer.git" \
        "$DEPS_BASE gcc meson ninja-build pkgconf-pkg-config pipewire-devel ncurses-devel inih-devel" \
        --ref "v${V[pipemixer]}"
    ;;
richcolors)
    build_pkg richcolors "${V[richcolors]}" \
        "https://github.com/Rizen54/richcolors.git" \
        "$DEPS_BASE" \
        --arch noarch
    ;;
neg-pretty-printer)
    build_pkg neg-pretty-printer "${V[neg-pretty-printer]}" \
        "" \
        "$DEPS_PYTHON" \
        --arch noarch --local-source /build/pretty-printer
    ;;
choose)
    build_pkg choose "${V[choose]}" \
        "https://github.com/theryangeary/choose.git" \
        "$DEPS_RUST" \
        --ref "v${V[choose]}"
    ;;
ouch)
    build_pkg ouch "${V[ouch]}" \
        "https://github.com/ouch-org/ouch.git" \
        "$DEPS_RUST gcc-c++ clang clang-devel" \
        --ref "${V[ouch]}"
    ;;
htmlq)
    build_pkg htmlq "${V[htmlq]}" \
        "https://github.com/mgdm/htmlq.git" \
        "$DEPS_RUST" \
        --ref "v${V[htmlq]}"
    ;;
erdtree)
    build_pkg erdtree "${V[erdtree]}" \
        "https://github.com/solidiquis/erdtree.git" \
        "$DEPS_RUST" \
        --ref "v${V[erdtree]}"
    ;;
viu)
    build_pkg viu "${V[viu]}" \
        "https://github.com/atanunq/viu.git" \
        "$DEPS_RUST" \
        --ref "v${V[viu]}"
    ;;
fclones)
    build_pkg fclones "${V[fclones]}" \
        "https://github.com/pkolaczk/fclones.git" \
        "$DEPS_RUST" \
        --ref "v${V[fclones]}"
    ;;
grex)
    build_pkg grex "${V[grex]}" \
        "https://github.com/pemistahl/grex.git" \
        "$DEPS_RUST" \
        --ref "v${V[grex]}"
    ;;
kmon)
    build_pkg kmon "${V[kmon]}" \
        "https://github.com/orhun/kmon.git" \
        "$DEPS_RUST" \
        --ref "v${V[kmon]}"
    ;;
jujutsu)
    build_pkg jujutsu "${V[jujutsu]}" \
        "https://github.com/jj-vcs/jj.git" \
        "$DEPS_RUST openssl-devel pkgconf-pkg-config cmake" \
        --ref "v${V[jujutsu]}"
    ;;
zfxtop)
    build_pkg zfxtop "${V[zfxtop]}" \
        "https://github.com/ssleert/zfxtop.git" \
        "$DEPS_GO" \
        --ref "${V[zfxtop]}"
    ;;
pup)
    build_pkg pup "${V[pup]}" \
        "https://github.com/ericchiang/pup.git" \
        "$DEPS_GO" \
        --ref "v${V[pup]}"
    ;;
scc)
    build_pkg scc "${V[scc]}" \
        "https://github.com/boyter/scc.git" \
        "$DEPS_GO" \
        --ref "v${V[scc]}"
    ;;
ctop)
    build_pkg ctop "${V[ctop]}" \
        "https://github.com/bcicen/ctop.git" \
        "$DEPS_GO" \
        --ref "v${V[ctop]}"
    ;;
dive)
    build_pkg dive "${V[dive]}" \
        "https://github.com/wagoodman/dive.git" \
        "$DEPS_GO" \
        --ref "v${V[dive]}"
    ;;
zk)
    build_pkg zk "${V[zk]}" \
        "https://github.com/zk-org/zk.git" \
        "$DEPS_GO gcc" \
        --ref "v${V[zk]}"
    ;;
git-filter-repo)
    build_pkg git-filter-repo "${V[git-filter-repo]}" \
        "https://github.com/newren/git-filter-repo.git" \
        "$DEPS_BASE" \
        --ref "v${V[git-filter-repo]}" --arch noarch
    ;;
epr)
    build_pkg epr "${V[epr]}" \
        "https://github.com/wustho/epr.git" \
        "$DEPS_BASE" \
        --ref "v${V[epr]}" --arch noarch
    ;;
lutgen)
    build_pkg lutgen "${V[lutgen]}" \
        "https://github.com/ozwaldorf/lutgen-rs.git" \
        "$DEPS_RUST" \
        --ref "v${V[lutgen]}"
    ;;
taplo)
    build_pkg taplo "${V[taplo]}" \
        "https://github.com/tamasfe/taplo.git" \
        "$DEPS_RUST openssl-devel pkgconf-pkg-config" \
        --ref "${V[taplo]}"
    ;;
gist)
    build_pkg gist "${V[gist]}" \
        "https://github.com/defunkt/gist.git" \
        "$DEPS_BASE ruby rubygem-rake" \
        --ref "v${V[gist]}" --arch noarch
    ;;
xxh)
    build_pkg xxh "${V[xxh]}" \
        "https://github.com/xxh/xxh.git" \
        "$DEPS_PYTHON" \
        --ref "${V[xxh]}" --arch noarch
    ;;
nerdctl)
    build_pkg nerdctl "${V[nerdctl]}" \
        "https://github.com/containerd/nerdctl.git" \
        "$DEPS_GO" \
        --ref "v${V[nerdctl]}"
    ;;
rapidgzip)
    build_pkg rapidgzip "${V[rapidgzip]}" \
        "https://github.com/mxmlnkn/rapidgzip.git" \
        "$DEPS_PYTHON gcc-c++ nasm" \
        --ref "rapidgzip-v${V[rapidgzip]}" --recursive
    ;;
scour)
    build_pkg scour "${V[scour]}" \
        "https://github.com/scour-project/scour.git" \
        "$DEPS_BASE python3-devel" \
        --ref "v${V[scour]}" --arch noarch
    ;;
iosevka)
    # Custom: different source dir naming, git checkout, extra source file, different spec name
    IOSEVKA_RPM_NAME="iosevka-neg-fonts-${V[iosevka]}-2.fc43.noarch.rpm"
    if [ -f "/build/rpms/${IOSEVKA_RPM_NAME}" ]; then
        echo "Iosevka RPM (${IOSEVKA_RPM_NAME}) already exists, skipping."
    else
        dnf install -y dnf-plugins-core
        rm -f /etc/yum.repos.d/fedora-cisco-openh264.repo
        dnf install -y --skip-broken make gcc git nodejs npm rpm-build ttfautohint python3-pip python3-fonttools python3-setuptools python3-wheel fontforge

        IOSEVKA_SOURCE_DIR="${RPM_BUILD_ROOT}/BUILD/iosevka-source-${V[iosevka]}"
        if [ ! -d "${IOSEVKA_SOURCE_DIR}" ]; then
            mkdir -p "${RPM_BUILD_ROOT}/BUILD"
            git clone --depth 1 https://github.com/be5invis/Iosevka.git "${IOSEVKA_SOURCE_DIR}"
            cd "${IOSEVKA_SOURCE_DIR}"
            git checkout "v${V[iosevka]}" || echo "Warning: Tag v${V[iosevka]} not found, proceeding with master/main branch."
            cd -
        fi
        tar -czf "${SOURCES_DIR}/iosevka-source-${V[iosevka]}.tar.gz" -C "${RPM_BUILD_ROOT}/BUILD" "iosevka-source-${V[iosevka]}"
        cp "/build/iosevka-neg.toml" "${SOURCES_DIR}/iosevka-neg.toml"
        cp /build/salt/specs/iosevka.spec "${SPECS_DIR}/iosevka-neg-fonts.spec"

        rpmbuild --define "_topdir ${RPM_BUILD_ROOT}" -ba "${SPECS_DIR}/iosevka-neg-fonts.spec"

        find "${RPMS_DIR}" -name "iosevka-neg-fonts-*.rpm" -exec cp {} /build/rpms/ \;
    fi
    ;;
bandwhich)
    build_pkg bandwhich "${V[bandwhich]}" \
        "https://github.com/imsnif/bandwhich.git" \
        "$DEPS_RUST" \
        --ref "v${V[bandwhich]}"
    ;;
xh)
    build_pkg xh "${V[xh]}" \
        "https://github.com/ducaale/xh.git" \
        "$DEPS_RUST" \
        --ref "v${V[xh]}"
    ;;
curlie)
    build_pkg curlie "${V[curlie]}" \
        "https://github.com/rs/curlie.git" \
        "$DEPS_GO" \
        --ref "v${V[curlie]}"
    ;;
doggo)
    build_pkg doggo "${V[doggo]}" \
        "https://github.com/mr-karan/doggo.git" \
        "$DEPS_GO" \
        --ref "v${V[doggo]}"
    ;;
carapace)
    build_pkg carapace "${V[carapace]}" \
        "https://github.com/carapace-sh/carapace-bin.git" \
        "$DEPS_GO" \
        --ref "v${V[carapace]}"
    ;;
wallust)
    build_pkg wallust "${V[wallust]}" \
        "https://codeberg.org/explosion-mental/wallust.git" \
        "$DEPS_RUST" \
        --ref "${V[wallust]}"
    ;;
wl-clip-persist)
    build_pkg wl-clip-persist "${V[wl-clip-persist]}" \
        "https://github.com/Linus789/wl-clip-persist.git" \
        "$DEPS_RUST" \
        --ref "v${V[wl-clip-persist]}"
    ;;
quickshell)
    build_pkg quickshell "${V[quickshell]}" \
        "https://github.com/quickshell-mirror/quickshell.git" \
        "$DEPS_BASE cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel qt6-qtshadertools-devel qt6-qtwayland-devel qt6-qtsvg-devel spirv-tools cli11-devel jemalloc-devel wayland-devel wayland-protocols-devel libdrm-devel mesa-libgbm-devel mesa-libEGL-devel pipewire-devel pam-devel polkit-devel glib2-devel libxcb-devel xcb-util-devel" \
        --ref "v${V[quickshell]}" \
        --dnf-flags "--skip-unavailable --disablerepo=updates"
    ;;
swayosd)
    build_pkg swayosd "${V[swayosd]}" \
        "https://github.com/ErikReider/SwayOSD.git" \
        "$DEPS_RUST meson ninja-build pkgconf-pkg-config glib2-devel sassc gtk4-devel gtk4-layer-shell-devel pulseaudio-libs-devel libinput-devel libevdev-devel systemd-devel dbus-devel" \
        --ref "v${V[swayosd]}"
    ;;
xdg-desktop-portal-termfilechooser)
    build_pkg xdg-desktop-portal-termfilechooser "${V[xdg-desktop-portal-termfilechooser]}" \
        "https://github.com/GermainZ/xdg-desktop-portal-termfilechooser.git" \
        "$DEPS_BASE gcc meson ninja-build pkgconf-pkg-config inih-devel systemd-devel scdoc"
    ;;
bucklespring)
    build_pkg bucklespring "${V[bucklespring]}" \
        "https://github.com/zevv/bucklespring.git" \
        "$DEPS_BASE gcc make pkgconf-pkg-config openal-soft-devel alure-devel libX11-devel libXtst-devel" \
        --ref "v${V[bucklespring]}"
    ;;
taoup)
    build_pkg taoup "${V[taoup]}" \
        "https://github.com/globalcitizen/taoup.git" \
        "$DEPS_BASE ruby" \
        --ref "v${V[taoup]}" --arch noarch
    ;;
newsraft)
    build_pkg newsraft "${V[newsraft]}" \
        "https://codeberg.org/newsraft/newsraft.git" \
        "$DEPS_BASE gcc make ncurses-devel libcurl-devel yajl-devel gumbo-parser-devel sqlite-devel expat-devel scdoc" \
        --ref "newsraft-${V[newsraft]}"
    ;;
unflac)
    build_pkg unflac "${V[unflac]}" \
        "https://git.sr.ht/~ft/unflac" \
        "$DEPS_GO" \
        --ref "${V[unflac]}"
    ;;
albumdetails)
    build_pkg albumdetails "${V[albumdetails]}" \
        "https://github.com/neg-serg/albumdetails.git" \
        "$DEPS_BASE gcc make taglib-devel" \
        --source-dir "albumdetails-master"
    ;;
cmake-language-server)
    build_pkg cmake-language-server "${V[cmake-language-server]}" \
        "https://github.com/regen100/cmake-language-server.git" \
        "$DEPS_PYTHON" \
        --ref "v${V[cmake-language-server]}" --arch noarch
    ;;
nginx-language-server)
    build_pkg nginx-language-server "${V[nginx-language-server]}" \
        "https://github.com/pappasam/nginx-language-server.git" \
        "$DEPS_PYTHON" \
        --ref "v${V[nginx-language-server]}"
    ;;
systemd-language-server)
    build_pkg systemd-language-server "${V[systemd-language-server]}" \
        "https://github.com/psacawa/systemd-language-server.git" \
        "$DEPS_PYTHON gcc libxml2-devel libxslt-devel" \
        --ref "${V[systemd-language-server]}"
    ;;
croc)
    build_pkg croc "${V[croc]}" \
        "https://github.com/schollz/croc.git" \
        "$DEPS_GO" \
        --ref "v${V[croc]}"
    ;;
faker)
    build_pkg faker "${V[faker]}" \
        "https://github.com/joke2k/faker.git" \
        "$DEPS_PYTHON" \
        --ref "v${V[faker]}" --arch noarch
    ;;
speedtest-go)
    build_pkg speedtest-go "${V[speedtest-go]}" \
        "https://github.com/showwin/speedtest-go.git" \
        "$DEPS_GO" \
        --ref "v${V[speedtest-go]}"
    ;;
greetd)
    build_pkg greetd "${V[greetd]}" \
        "https://git.sr.ht/~kennylevinsen/greetd" \
        "$DEPS_RUST scdoc pam-devel selinux-policy-devel systemd systemd-devel systemd-rpm-macros" \
        --ref "${V[greetd]}" \
        --extra-sources "/build/salt/greetd-files/greetd.pam /build/salt/greetd-files/greetd-greeter.pam /build/salt/greetd-files/greetd.sysusers /build/salt/greetd-files/greetd.tmpfiles /build/salt/greetd-files/greetd.fc"
    ;;
rustnet)
    build_pkg rustnet "${V[rustnet]}" \
        "https://github.com/domcyrus/rustnet.git" \
        "$DEPS_RUST libpcap-devel" \
        --ref "v${V[rustnet]}"
    ;;
*)
    echo "Unknown package: $1" >&2
    exit 1
    ;;
esac
