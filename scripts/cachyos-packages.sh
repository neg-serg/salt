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

# Retry wrapper for transient network failures (AUR RPC resets, mirror hiccups)
# Usage: retry <max_attempts> <description> <command...>
retry() {
    local max_attempts="$1" desc="$2"
    shift 2
    local attempt=1 delay=10
    while true; do
        echo "==> [$desc] attempt $attempt/$max_attempts"
        if "$@"; then
            return 0
        fi
        if (( attempt >= max_attempts )); then
            echo "==> [$desc] FAILED after $max_attempts attempts" >&2
            return 1
        fi
        echo "==> [$desc] failed, retrying in ${delay}s..."
        sleep "$delay"
        (( attempt++ ))
        (( delay *= 2 ))
    done
}

# ===================================================================
# OFFICIAL PACKAGES (pacman)
# ===================================================================

PACMAN_PKGS=(
    # --- Archives & Compression ---
    lbzip2              # parallel bzip2 compressor
    pbzip2              # parallel bzip2 compressor (alternative)
    pigz                # parallel gzip compressor
    unarchiver          # unar/lsar: universal archive extractor

    # --- Development ---
    android-tools       # adb, fastboot
    ansible             # IT automation / config management
    bpftrace            # eBPF tracing language
    rust                # Rust compiler + cargo
    clang               # LLVM C/C++/ObjC compiler
    cmake               # cross-platform build system
    difftastic          # structural diff tool
    dbus                # D-Bus IPC system
    direnv              # per-directory environment variables
    dkms                # dynamic kernel module support
    elfutils            # ELF binary tools (eu-readelf, eu-strip)
    gcc                 # GNU C/C++ compiler
    gdb                 # GNU debugger
    graphviz            # graph visualization (dot, neato)
    helix               # modal text editor (Rust, LSP-native)
    hexyl               # hex viewer with colored output
    hyperfine           # command-line benchmarking tool
    just                # command runner (modern make alternative)
    # linux-cachyos-lts-headers already in bootstrap
    lldb                # LLVM debugger
    openocd             # on-chip debugger for embedded
    nodejs              # JavaScript runtime
    npm                 # Node.js package manager
    perf                # Linux performance profiling
    pgcli               # PostgreSQL CLI with autocomplete
    pipewire            # audio/video server
    ruff                # fast Python linter + formatter
    shellcheck          # shell script static analysis
    shfmt               # shell script formatter
    strace              # system call tracer
    tree-sitter-cli     # tree-sitter grammar tool
    valgrind            # memory debugging / profiling
    yamllint            # YAML linter

    # --- File Management ---
    7zip                # 7-Zip file archiver
    bat                 # cat clone with syntax highlighting
    borg                # deduplicating backup (borgbackup)
    convmv              # filename encoding converter
    ddrescue            # data recovery from failing drives
    dos2unix            # line ending converter
    dust                # disk usage tree (du alternative)
    enca                # character encoding detector
    fd                  # fast find alternative
    fzf                 # fuzzy finder (Ctrl-R, Ctrl-T, Alt-C)
    inotify-tools       # inotifywait/inotifywatch filesystem events
    ncdu                # interactive disk usage analyzer
    plocate             # fast file locate
    ripgrep             # fast recursive grep
    rclone              # cloud storage sync (rsync for cloud)
    testdisk            # partition recovery + undelete

    # --- Fonts ---
    # material-icons-fonts → AUR (ttf-material-design-icons-git)
    ttf-material-symbols-variable  # Material Symbols (Outlined/Rounded/Sharp) for quickshell

    # --- Media ---
    carla               # audio plugin host (JACK/LV2/VST)
    beets               # music library manager + tagger
    cava                # console audio visualizer
    cdparanoia          # audio CD ripper
    chafa               # image-to-terminal renderer
    darktable           # RAW photo editor (Lightroom alternative)
    ffmpegthumbnailer   # video thumbnail generator
    helvum              # PipeWire patchbay GUI
    jpegoptim           # JPEG optimizer
    lsp-plugins         # Linux Studio Plugins (audio DSP)
    mediainfo           # media file metadata viewer
    mpd                 # music player daemon
    mpc                 # MPD command-line client
    mpv                 # video player
    optipng             # PNG optimizer
    perl-image-exiftool # EXIF/IPTC/XMP metadata tool
    chromaprint         # audio fingerprinting (provides fpcalc)
    picard              # MusicBrainz audio tagger GUI
    pngquant            # lossy PNG compressor
    qpwgraph            # PipeWire graph editor (Qt GUI)
    rawtherapee         # RAW photo processor
    sonic-visualiser    # audio waveform/spectrogram viewer
    wiremix             # TUI PipeWire mixer
    supercollider       # audio synthesis / algorithmic composition
    sc3-plugins         # SuperCollider community plugins
    sox                 # audio processing CLI (Swiss Army knife)
    swayimg             # Wayland image viewer
    tesseract           # OCR engine
    tesseract-data-eng  # Tesseract English language data
    tesseract-data-rus  # Tesseract Russian language data
    zbar                # barcode/QR reader
    media-player-info   # media player capability database

    # --- Media (tools) ---
    imagemagick         # image manipulation suite (convert, identify)
    yt-dlp              # video downloader (YouTube, etc.)

    # --- Monitoring & System ---
    atop                # advanced system/process monitor
    bucklespring        # mechanical keyboard sound simulator
    btop                # resource monitor (htop alternative)
    lsof                # list open files / who holds a file
    powertop            # power consumption analyzer
    s-tui               # terminal CPU stress test + monitor
    multipath-tools     # device-mapper multipath I/O
    cpufetch            # CPU architecture info display
    fastfetch           # system info display (neofetch alternative)
    fio                 # flexible I/O benchmark
    gptfdisk            # GPT partition table tools (gdisk)
    goaccess            # real-time web log analyzer
    hwinfo              # hardware detection tool
    inxi                # system information script
    ioping              # I/O latency benchmark
    iotop-c             # per-process I/O monitor (C rewrite)
    kexec-tools         # fast kernel reboot (skip BIOS)
    liquidctl           # AIO/RGB liquid cooler control
    lm_sensors          # hardware sensor monitoring
    lnav                # log file navigator with highlighting
    lshw                # hardware lister
    memtester           # RAM stress tester
    nvtop               # GPU process monitor (NVIDIA/AMD/Intel)
    parted              # partition editor
    progress            # show progress of coreutils commands
    pv                  # pipe viewer (data throughput meter)
    schedtool           # CPU scheduler policy setter
    smartmontools       # disk S.M.A.R.T. monitoring
    sysstat             # system performance tools (sar, iostat)
    vnstat              # network traffic monitor
    cpupower            # CPU frequency scaling control
    turbostat           # Intel CPU power/frequency stats

    # --- Network ---
    aria2               # multi-protocol download accelerator
    fping               # fast parallel ping
    freerdp             # RDP client (remote desktop)
    sshfs               # mount remote FS over SSH (FUSE)
    geoip               # IP geolocation library + tools
    geoip-database      # GeoIP country database
    httpie              # user-friendly HTTP client
    iftop               # network bandwidth monitor per connection
    iperf3              # network throughput benchmark
    iwd                 # Intel wireless daemon (wpa_supplicant alternative)
    nicotine+           # Soulseek P2P music sharing client
    nmap                # network scanner + ncat
    socat               # multipurpose relay (socket proxy, Hyprland IPC)
    ollama              # local LLM inference server
    prettyping          # colorful ping wrapper
    sshpass             # non-interactive SSH password auth
    streamlink          # stream extractor (Twitch, YouTube, etc.)
    telegram-desktop    # Telegram messenger client
    traceroute          # network path tracer
    ttyd                # share terminal over web (TTY → HTTP)
    whois               # domain/IP WHOIS lookup
    vdirsyncer          # CalDAV/CardDAV synchronizer
    transmission-gtk    # BitTorrent client (GTK)
    w3m                 # terminal web browser
    waypipe             # Wayland remote display (SSH forwarding)
    wayvnc              # VNC server for Wayland compositors
    mtr                 # traceroute + ping combined
    unbound             # recursive DNS resolver
    zmap                # fast Internet-wide port scanner

    # --- Shell & Tools ---
    abduco              # session management (detach/attach)
    age                 # modern file encryption (GPG alternative)
    asciinema           # terminal session recorder
    cowsay              # ASCII cow with speech bubble
    libnotify           # desktop notification library (notify-send)
    dash                # POSIX shell (fast /bin/sh)
    entr                # run command on file changes
    expect              # automated interactive program control
    figlet              # ASCII art text banners
    fortune-mod         # random quotes / fortune cookies
    github-cli          # GitHub CLI (gh)
    git-lfs             # Git Large File Storage
    glow                # terminal Markdown renderer
    gopass              # password manager (pass-compatible, GPG)
    himalaya            # CLI email client (IMAP/SMTP)
    isync               # IMAP mailbox sync (mbsync)
    jc                  # JSON converter for CLI output
    lolcat              # rainbow text colorizer
    lowdown             # Markdown → terminal/HTML/roff renderer
    miller              # CSV/JSON/tabular data processor (mlr)
    minicom             # serial port terminal emulator
    moreutils           # extra Unix tools (sponge, ts, parallel, etc.)
    mtools              # MS-DOS filesystem tools (mcopy, mdir)
    neomutt             # terminal email client (mutt fork)
    parallel            # shell command parallelizer
    pastel              # color manipulation CLI (HSL, mix, etc.)
    pwgen               # random password generator
    qrencode            # QR code generator
    recoll              # full-text desktop search engine
    reptyr              # re-parent process to new terminal
    rlwrap              # readline wrapper for any CLI
    sad                 # search and replace (sed + fzf)
    sqlite              # SQLite database engine + CLI
    tealdeer            # fast tldr pages client (Rust)
    tmux                # terminal multiplexer
    toilet              # fancy ASCII art text (figlet alternative)
    translate-shell     # Google Translate CLI
    udiskie             # automounter for removable media
    ugrep               # ultra-fast grep with fuzzy/archive support
    urlscan             # URL extractor from emails/text
    urlwatch            # web page change monitor
    go-yq               # YAML/JSON/XML processor (jq for YAML)
    zathura             # keyboard-driven document viewer
    zathura-pdf-poppler # PDF plugin for zathura
    zoxide              # smart cd with frecency (z/autojump alternative)
    zsh                 # Z shell

    # --- Wayland / Desktop ---
    distrobox           # run any Linux distro in containers
    hyprland            # tiling Wayland compositor
    hypridle            # Hyprland idle daemon
    hyprlock            # Hyprland lock screen
    hyprpaper           # Hyprland wallpaper daemon
    kitty               # GPU-accelerated terminal emulator
    podman              # rootless container engine (Docker alternative)
    xdg-desktop-portal-hyprland  # XDG desktop portal for Hyprland
    cliphist            # Wayland clipboard history manager
    dunst               # notification daemon
    rofi                # application launcher / dmenu replacement
    swappy              # Wayland screenshot editor / annotator
    swaybg              # Wayland wallpaper setter
    swww                # animated Wayland wallpaper daemon
    wev                 # Wayland event viewer (xev equivalent)
    wf-recorder         # Wayland screen recorder
    wtype               # Wayland keyboard input tool (xdotool equivalent)
    ydotool             # input automation (mouse/keyboard, Wayland)
    quickshell          # Qt6/QML Wayland shell toolkit
    swayosd             # on-screen display for Wayland (volume/brightness)
    wl-clip-persist     # keep Wayland clipboard after app closes
    greetd              # minimal login manager (greeter daemon)
    greetd-regreet      # GTK4 greeter for greetd

    # --- Gaming & Emulation (disabled for now, Steam/Proton handled separately) ---
    # 0ad                 # RTS game (Age of Empires-like)
    # angband             # classic roguelike dungeon crawler
    # crawl-tiles         # Dungeon Crawl Stone Soup (graphical)
    # endless-sky         # 2D space trading / combat game
    # gnuchess            # chess engine
    # nethack             # classic roguelike
    # openmw              # open Morrowind engine reimplementation
    # retroarch           # multi-system emulator frontend
    # supertux            # 2D platformer (Mario-like)
    # wesnoth             # turn-based strategy game
    # xaos                # real-time fractal zoomer
    # xonotic             # fast-paced FPS (Quake-like)

    # --- Security ---
    hashcat             # GPU-accelerated password recovery
    pcsc-tools          # smartcard reader tools
    tcpdump             # packet capture / analyzer
    wireshark-cli       # network protocol analyzer (tshark)

    # --- Virtualization ---
    libvirt             # virtualization API (KVM/QEMU management)
    dnsmasq             # lightweight DNS/DHCP (for libvirt NAT)
    qemu-desktop        # full system emulator (KVM backend)
    virt-manager        # libvirt GUI manager

    # --- Services ---
    avahi               # mDNS/DNS-SD service discovery
    nss-mdns            # mDNS hostname resolution (NSS module)
    grafana             # monitoring dashboard platform
    samba               # SMB/CIFS file sharing

    # --- Desktop ---
    corectrl            # AMD GPU/CPU control panel
    hunspell-ru         # Russian spellcheck dictionary
    nuspell             # modern spellchecker
    kvantum             # SVG-based Qt6 theme engine
    kvantum-qt5         # SVG-based Qt5 theme engine
    openrgb             # RGB lighting control
    qt5ct               # Qt5 appearance configuration tool
    qt6ct               # Qt6 appearance configuration tool
    texlive-basic       # TeX Live base distribution

    # --- Python ---
    python-pipx         # install Python apps in isolated envs

    # --- Version Control ---
    chezmoi             # dotfile manager
    diff-so-fancy       # human-readable git diff
    etckeeper           # track /etc in version control
    git                 # distributed version control
    git-crypt           # transparent git file encryption
    git-delta           # syntax-highlighting pager for git diff
    onefetch            # git repo info display (neofetch for repos)
    tig                 # text-mode git interface

    # --- Former custom RPMs now in official repos ---
    bandwhich           # per-process network bandwidth monitor
    choose              # cut/awk alternative (field selector)
    erdtree             # multi-threaded file tree (du + tree)
    fclones             # efficient duplicate file finder
    grex                # regex generator from examples
    htmlq               # jq for HTML (CSS selector extraction)
    jujutsu             # Git-compatible VCS (jj)
    kmon                # kernel module monitor
    ouch                # painless (de)compression CLI
    taplo-cli           # TOML toolkit (formatter, linter, LSP)
    viu                 # terminal image viewer
    xh                  # friendly HTTP client (httpie alternative, Rust)
    curlie              # curl + httpie hybrid
    nerdctl             # containerd CLI (Docker-compatible)
    ctop                # container metrics top
    dive                # Docker/OCI image layer explorer
    git-filter-repo     # fast git history rewriting
    scour               # SVG optimizer

    spotifyd            # headless Spotify daemon
    sbctl               # Secure Boot key manager
    patchmatrix         # JACK patchbay matrix GUI
)

# ===================================================================
# AUR PACKAGES (paru)
# ===================================================================

AUR_PKGS=(
    # --- From main package list ---
    patool              # universal archive manager (wrapper)
    act-bin             # run GitHub Actions locally
    # hxtools             # misc Linux utilities collection — FTBFS on CachyOS
    ttf-material-design-icons-git  # Material Design icon font
    advancecomp         # recompression tools (advpng, advzip)
    id3v2               # ID3v2 tag editor
    mpdas              # MPD AudioScrobbler (Last.fm scrobbler)
    mpdris2             # MPRIS2 bridge for MPD
    raysession          # JACK session manager GUI
    hw-probe            # hardware probe collector
    # procdump            # process core dump generator (MS port) — FTBFS on CachyOS
    # below               # cgroup2 resource monitor (Facebook) — FTBFS on CachyOS
    dcfldd              # forensic dd with hashing
    freeze-bin          # code screenshot generator (Charm)
    goimapnotify        # IMAP IDLE notification daemon
    # hyprland-qtutils  # conflicts with hyprland-guiutils from official repos
    neo-matrix          # Matrix rain terminal effect
    # netmask             # IP address / netmask calculator — FTBFS on CachyOS
    no-more-secrets     # Sneakers movie decryption effect
    par                 # paragraph reformatter
    claude-code         # Claude AI coding assistant CLI
    salt                # infrastructure configuration management
    pyprland            # Hyprland plugin framework (Python)
    wlogout             # Wayland logout menu
    # abuse               # side-scrolling action game
    # dosbox-staging      # DOS emulator (modern fork)
    # fheroes2            # Heroes of Might and Magic II engine
    # flare-game          # action RPG (Diablo-like)
    # bottles             # Wine prefix manager (GUI)
    ddccontrol          # DDC/CI monitor control
    git-extras          # extra git commands (git-summary, etc.)

    overskride-bin      # Bluetooth GTK4 client
    dualsensectl        # DualSense controller LED/haptics control
    # espanso-wayland     # text expander (Wayland build) — FTBFS on CachyOS
    brutefir            # convolution audio engine

    # --- Packages not in official Arch repos ---
    jdupes              # duplicate file finder (fast, jody's)
    rmlint              # filesystem lint (duplicates, broken links)
    blktrace            # block I/O tracer
    vmtouch             # file page cache control

    # --- Former custom RPMs now in AUR ---
    lutgen-bin          # color palette LUT generator
    wallust             # wallpaper-based colorscheme generator
    carapace-bin        # multi-shell completion engine
    doggo               # DNS client (dig alternative)
    massren             # bulk file rename with editor
    pup-bin             # HTML stream processor (jq for HTML)
    scc                 # source code line counter (fast)
    # zfxtop              # TUI process/system monitor (Go) — FTBFS on CachyOS
    zk                  # Zettelkasten CLI note manager
    pipemixer           # TUI PipeWire mixer (C)
    xdg-desktop-portal-termfilechooser-boydaihungst-git  # terminal file chooser portal (yazi)
    epr-git             # terminal EPUB reader
    python-rapidgzip    # fast parallel gzip decompressor
    # xxh-git             # bring your shell through SSH — FTBFS on CachyOS
    gist                # GitHub Gist CLI (Ruby)
    newsraft            # terminal RSS/Atom reader
    unflac              # FLAC + cue splitter
    cmake-language-server  # CMake LSP server
    # nginx-language-server    # check AUR availability
    # systemd-language-server  # check AUR availability

    # --- VPN ---
    amneziawg-tools     # AmneziaWG VPN userspace tools
    amneziawg-dkms      # AmneziaWG kernel module (DKMS)

    # --- Snapshot boot integration ---
    limine-snapper-sync # sync Btrfs snapshots to Limine boot entries
)

# ===================================================================
# CUSTOM PKGBUILD PACKAGES (makepkg)
# ===================================================================
# Packages with no official/AUR equivalent, built from local PKGBUILDs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SALT_DIR="$(dirname "$SCRIPT_DIR")"
PKGBUILD_DIR="${SALT_DIR}/build/pkgbuilds"

# iosevka-neg-fonts last: 2+ hour build
CUSTOM_PKGS=(raise neg-pretty-printer richcolors albumdetails taoup iosevka-neg-fonts)

pkgbuild_install() {
    # Provide iosevka design config alongside its PKGBUILD
    cp "${SALT_DIR}/build/iosevka-neg.toml" "${PKGBUILD_DIR}/iosevka-neg-fonts/"

    # iosevka-neg-fonts needs ttfautohint (AUR-only, makepkg can't install it)
    if ! pacman -Q ttfautohint &>/dev/null; then
        echo "  Installing ttfautohint from AUR (needed for iosevka build)..."
        su - neg -c "paru -S --needed --noconfirm --skipreview ttfautohint"
    fi

    for pkg in "${CUSTOM_PKGS[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            echo "  $pkg already installed, skipping"
            continue
        fi
        if [[ ! -f "${PKGBUILD_DIR}/${pkg}/PKGBUILD" ]]; then
            echo "  WARNING: no PKGBUILD for ${pkg}, skipping" >&2
            continue
        fi
        echo "  Building ${pkg}..."
        sudo -u neg bash -c "cd '${PKGBUILD_DIR}/${pkg}' && makepkg -sfC --noconfirm"
        pacman -U --noconfirm "${PKGBUILD_DIR}/${pkg}/"*.pkg.tar.zst
    done

    # Ruby gem for taoup color output
    gem install ansi --no-document --no-user-install 2>/dev/null || true
}

# ===================================================================
# Install
# ===================================================================

pacman_install() {
    # Refresh databases — mirrors may have synced since last failure
    pacman -Sy --noconfirm
    # Delete partial/corrupted cached downloads that would block re-download
    find /var/cache/pacman/pkg/ -name '*.part' -delete 2>/dev/null || true
    # --needed skips already-installed packages (safe after partial installs)
    pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
}

paru_install() {
    # -Sy refreshes databases; --needed skips already-installed packages
    su - neg -c "paru -Sy --needed --noconfirm --noprovides --skipreview ${AUR_PKGS[*]}"
}

echo "==> Installing official packages (pacman)..."
retry 3 "pacman" pacman_install

echo ""
echo "==> Installing AUR packages (paru as user neg)..."
retry 5 "paru/AUR" paru_install || echo "WARNING: some AUR packages failed (non-fatal, continuing)"

echo ""
echo "==> Building and installing custom packages (makepkg as user neg)..."
echo "    NOTE: iosevka-neg-fonts takes 2+ hours to build"
pkgbuild_install

echo ""
echo "==> Done. All packages installed."
