#!/usr/bin/env bash
# Install all user packages on CachyOS after bootstrap
# Run as root after first boot (or from arch-chroot)
#
# Usage:
#   sudo ./scripts/cachyos-packages.sh
#
# Requires: paru (installed by bootstrap)

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "error: must run as root" >&2
    exit 1
fi

# ===================================================================
# OFFICIAL PACKAGES (pacman)
# ===================================================================

PACMAN_PKGS=(
    # --- Archives & Compression ---
    lbzip2
    pbzip2
    pigz
    unarchiver          # Fedora: unar

    # --- Development ---
    android-tools
    ansible
    bpftrace
    rust                # includes cargo
    clang
    cmake
    difftastic
    dbus                # Fedora: dbus-devel (Arch includes headers)
    direnv
    dkms
    elfutils
    gcc
    gdb
    graphviz
    helix
    hexyl
    hyperfine
    just
    # linux-cachyos-headers already in bootstrap
    lldb
    openocd
    nodejs
    npm
    perf
    pgcli
    pipewire            # Fedora: pipewire-devel (Arch includes headers)
    ruff
    shellcheck          # Fedora: ShellCheck
    shfmt
    strace
    valgrind
    yamllint

    # --- File Management ---
    bat
    borg                # Fedora: borgbackup
    convmv
    ddrescue
    dos2unix
    dust                # Fedora: du-dust
    enca
    fd                  # Fedora: fd-find
    jdupes
    ncdu
    plocate
    ripgrep
    rclone
    rmlint
    testdisk

    # --- Fonts ---
    # material-icons-fonts → AUR

    # --- Media ---
    carla               # Fedora: Carla
    beets
    cava
    cdparanoia
    chafa
    darktable
    ffmpegthumbnailer
    helvum
    jpegoptim
    lsp-plugins
    mediainfo
    mpd
    mpc
    mpv
    optipng
    perl-image-exiftool # Fedora: perl-Image-ExifTool
    chromaprint         # Fedora: chromaprint-tools (provides fpcalc)
    picard
    pngquant
    qpwgraph
    rawtherapee
    sonic-visualiser
    wiremix
    supercollider
    sox
    swayimg
    tesseract
    tesseract-data-eng
    tesseract-data-rus
    zbar
    media-player-info

    # --- Monitoring & System ---
    atop
    blktrace
    btop
    multipath-tools     # Fedora: device-mapper-multipath
    fastfetch
    fio
    gptfdisk            # Fedora: gdisk
    goaccess
    hwinfo
    inxi
    ioping
    iotop-c
    kexec-tools
    liquidctl
    lm_sensors
    lnav
    lshw
    memtester
    nvtop
    parted
    progress
    pv
    schedtool
    smartmontools
    sysstat
    vmtouch
    vnstat
    cpupower            # Fedora: kernel-tools (part 1)
    turbostat           # Fedora: kernel-tools (part 2)

    # --- Network ---
    aria2
    fping
    freerdp
    sshfs               # Fedora: fuse-sshfs
    geoip               # Fedora: GeoIP
    geoip-database
    httpie
    iftop
    iperf3              # Fedora: iperf
    iwd
    nicotine+
    nmap                # Fedora: nmap-ncat (ncat included)
    ollama
    prettyping
    sshpass
    streamlink
    telegram-desktop
    traceroute
    ttyd
    whois
    vdirsyncer
    transmission-gtk
    w3m
    waypipe
    wayvnc
    zmap

    # --- Shell & Tools ---
    abduco
    age
    asciinema
    cowsay
    libnotify
    dash
    entr
    expect
    figlet
    fortune-mod
    github-cli          # Fedora: gh
    git-lfs
    glow
    gopass
    jc
    lolcat
    lowdown
    miller
    minicom
    moreutils
    mtools
    neomutt
    parallel
    pastel
    pwgen
    recoll
    reptyr
    rlwrap
    sad
    sqlite
    tealdeer
    tmux
    toilet
    translate-shell
    udiskie
    ugrep
    urlscan
    urlwatch
    go-yq               # Fedora: yq (Mike Farah's Go version)
    zathura
    zathura-pdf-poppler
    zoxide
    zsh

    # --- Wayland ---
    cliphist
    dunst
    rofi-wayland        # Fedora: rofi
    screenkey
    swappy
    swaybg
    swww
    wev
    wf-recorder
    ydotool

    # --- Gaming & Emulation ---
    0ad
    angband
    endless-sky
    gnuchess
    nethack
    openmw
    retroarch
    supertux2           # Fedora: supertux
    wesnoth
    xonotic

    # --- Security ---
    hashcat
    pcsc-tools
    tcpdump
    wireshark-cli

    # --- Virtualization ---
    libvirt
    dnsmasq             # needed for libvirt NAT networking
    qemu-desktop        # Fedora: qemu-kvm
    virt-manager

    # --- Desktop ---
    corectrl
    hunspell-ru
    nuspell
    kvantum
    openrgb
    qt5ct
    texlive-basic       # Fedora: texlive-scheme-basic

    # --- Version Control ---
    chezmoi
    diff-so-fancy
    etckeeper
    git
    git-crypt
    git-delta
    onefetch
    tig

    # --- Former custom RPMs now in official repos ---
    bandwhich
    choose
    erdtree
    fclones
    grex
    htmlq
    jujutsu
    kmon
    ouch
    taplo-cli           # Fedora: taplo
    viu
    xh
    curlie
    duf
    nerdctl
    ctop
    dive
    git-filter-repo
    scour

    # --- Former COPR packages now in official repos ---
    spotifyd
    sbctl
    patchmatrix
)

# ===================================================================
# AUR PACKAGES (paru)
# ===================================================================

AUR_PKGS=(
    # --- From main package list ---
    patool
    act-bin              # Fedora: act
    hxtools
    ttf-material-design-icons-git  # Fedora: material-icons-fonts
    advancecomp
    id3v2
    mpdas
    mpdris2
    raysession
    hw-probe
    procdump
    s-tui
    below                # Facebook cgroup2 monitor
    cpufetch-git
    dcfldd
    freeze               # charmbracelet/freeze
    neo-matrix           # Fedora: neo
    netmask
    no-more-secrets
    par
    salt
    pyprland
    wlogout
    wtype
    abuse
    crawl                # Fedora: crawl-tiles
    dosbox-staging
    fheroes2
    flare-game           # Fedora: flare
    xaos
    bottles
    ddccontrol
    git-extras

    # --- Former COPR packages ---
    dualsensectl
    espanso-wayland
    himalaya-git
    brutefir
    sc3-plugins-git      # Fedora: supercollider-sc3-plugins

    # --- Former custom RPMs now in AUR ---
    lutgen-bin
    wallust
    carapace-bin
    doggo
    massren
    pup-bin
    scc
    zfxtop
    zk
    pipemixer
    xdg-desktop-portal-termfilechooser-git
    epr-git
    python-rapidgzip     # Fedora: rapidgzip
    xxh-git
    gist                 # Ruby gist CLI
    quickshell-git
    swayosd-git
    wl-clip-persist-git
    bucklespring-git
    newsraft
    unflac
    cmake-language-server
    # nginx-language-server    # check AUR availability
    # systemd-language-server  # check AUR availability

    # --- VPN ---
    amneziawg-tools
    amneziawg-dkms

    # --- Snapshot boot integration ---
    limine-snapper-sync
)

# ===================================================================
# PACKAGES NEEDING MANUAL BUILD (PKGBUILDs or custom)
# ===================================================================
# raise               — custom window raise tool
# neg-pretty-printer  — custom/personal
# richcolors          — custom/personal
# taoup               — Unix philosophy quotes
# albumdetails        — custom C tool
# iosevka-neg-fonts   — custom Iosevka font build

# ===================================================================
# Install
# ===================================================================

echo "==> Installing official packages (pacman)..."
pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

echo ""
echo "==> Installing AUR packages (paru as user neg)..."
su - neg -c "paru -S --needed --noconfirm ${AUR_PKGS[*]}"

echo ""
echo "==> Done. Packages needing manual build:"
echo "    raise, neg-pretty-printer, richcolors, taoup, albumdetails, iosevka-neg-fonts"
