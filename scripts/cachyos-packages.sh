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
    # linux-cachyos-headers already in bootstrap
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
    valgrind            # memory debugging / profiling
    yamllint            # YAML linter

    # --- File Management ---
    bat                 # cat clone with syntax highlighting
    borg                # deduplicating backup (borgbackup)
    convmv              # filename encoding converter
    ddrescue            # data recovery from failing drives
    dos2unix            # line ending converter
    dust                # disk usage tree (du alternative)
    enca                # character encoding detector
    fd                  # fast find alternative
    ncdu                # interactive disk usage analyzer
    plocate             # fast file locate
    ripgrep             # fast recursive grep
    rclone              # cloud storage sync (rsync for cloud)
    testdisk            # partition recovery + undelete

    # --- Fonts ---
    # material-icons-fonts → AUR (ttf-material-design-icons-git)

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
    sox                 # audio processing CLI (Swiss Army knife)
    swayimg             # Wayland image viewer
    tesseract           # OCR engine
    tesseract-data-eng  # Tesseract English language data
    tesseract-data-rus  # Tesseract Russian language data
    zbar                # barcode/QR reader
    media-player-info   # media player capability database

    # --- Monitoring & System ---
    atop                # advanced system/process monitor
    bucklespring        # mechanical keyboard sound simulator
    btop                # resource monitor (htop alternative)
    s-tui               # terminal CPU stress test + monitor
    multipath-tools     # device-mapper multipath I/O
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

    # --- Wayland ---
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

    # --- Gaming & Emulation ---
    0ad                 # RTS game (Age of Empires-like)
    angband             # classic roguelike dungeon crawler
    crawl-tiles         # Dungeon Crawl Stone Soup (graphical)
    endless-sky         # 2D space trading / combat game
    gnuchess            # chess engine
    nethack             # classic roguelike
    openmw              # open Morrowind engine reimplementation
    retroarch           # multi-system emulator frontend
    supertux            # 2D platformer (Mario-like)
    wesnoth             # turn-based strategy game
    xaos                # real-time fractal zoomer
    xonotic             # fast-paced FPS (Quake-like)

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

    # --- Desktop ---
    corectrl            # AMD GPU/CPU control panel
    hunspell-ru         # Russian spellcheck dictionary
    nuspell             # modern spellchecker
    kvantum             # SVG-based Qt theme engine
    openrgb             # RGB lighting control
    qt5ct               # Qt5 appearance configuration tool
    texlive-basic       # TeX Live base distribution

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
    duf                 # disk usage (df alternative)
    nerdctl             # containerd CLI (Docker-compatible)
    ctop                # container metrics top
    dive                # Docker/OCI image layer explorer
    git-filter-repo     # fast git history rewriting
    scour               # SVG optimizer

    # --- Former COPR packages now in official repos ---
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
    hxtools             # misc Linux utilities collection
    ttf-material-design-icons-git  # Material Design icon font
    advancecomp         # recompression tools (advpng, advzip)
    id3v2               # ID3v2 tag editor
    mpdas              # MPD AudioScrobbler (Last.fm scrobbler)
    mpdris2             # MPRIS2 bridge for MPD
    raysession          # JACK session manager GUI
    hw-probe            # hardware probe collector
    procdump            # process core dump generator (MS port)
    below               # cgroup2 resource monitor (Facebook)
    cpufetch-git        # CPU architecture info display
    dcfldd              # forensic dd with hashing
    freeze-bin          # code screenshot generator (Charm)
    neo-matrix          # Matrix rain terminal effect
    netmask             # IP address / netmask calculator
    no-more-secrets     # Sneakers movie decryption effect
    par                 # paragraph reformatter
    salt                # infrastructure configuration management
    pyprland            # Hyprland plugin framework (Python)
    wlogout             # Wayland logout menu
    abuse               # side-scrolling action game
    dosbox-staging      # DOS emulator (modern fork)
    fheroes2            # Heroes of Might and Magic II engine
    flare-game          # action RPG (Diablo-like)
    bottles             # Wine prefix manager (GUI)
    ddccontrol          # DDC/CI monitor control
    git-extras          # extra git commands (git-summary, etc.)

    # --- Former COPR packages ---
    dualsensectl        # DualSense controller LED/haptics control
    espanso-wayland     # text expander (Wayland build)
    himalaya-git        # CLI email client (IMAP/SMTP)
    brutefir            # convolution audio engine
    sc3-plugins-git     # SuperCollider community plugins

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
    zfxtop              # TUI process/system monitor (Go)
    zk                  # Zettelkasten CLI note manager
    pipemixer           # TUI PipeWire mixer (C)
    xdg-desktop-portal-termfilechooser-git  # terminal file chooser portal
    epr-git             # terminal EPUB reader
    python-rapidgzip    # fast parallel gzip decompressor
    xxh-git             # bring your shell through SSH
    gist                # GitHub Gist CLI (Ruby)
    quickshell-git      # Qt6/QML Wayland shell toolkit
    swayosd-git         # on-screen display for Wayland (volume/brightness)
    wl-clip-persist-git # keep Wayland clipboard after app closes
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
