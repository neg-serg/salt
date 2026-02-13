{% from 'host_config.jinja' import host %}
# Salt state for Fedora Silverblue
# Handles filesystem immutability

# Fix containers policy to allow podman to pull images
fix_containers_policy:
  file.managed:
    - name: /etc/containers/policy.json
    - contents: |
        {
            "default": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "transports":
                {
                    "docker-daemon":
                        {
                            "": [{"type":"insecureAcceptAnything"}]
                        }
                }
        }
    - user: root
    - group: root
    - mode: '0644'

system_timezone:
  timezone.system:
    - name: Europe/Moscow

system_locale_keymap:
  cmd.run:
    - name: |
        localectl set-locale LANG=en_US.UTF-8
        localectl set-x11-keymap ru,us
    - unless: |
        status=$(localectl status)
        echo "$status" | grep -q 'LANG=en_US.UTF-8' &&
        echo "$status" | grep -q 'X11 Layout.*ru'

system_hostname:
  cmd.run:
    - name: hostnamectl set-hostname {{ host.hostname }}
    - unless: test "$(hostname)" = "{{ host.hostname }}"

user_root:
  user.present:
    - name: root
    - shell: /usr/bin/zsh

user_neg:
  user.present:
    - name: neg
    - shell: /usr/bin/zsh
    - uid: 1000
    - gid: 1000

plugdev_group:
  group.present:
    - name: plugdev
    - system: True

# user.present groups broken on Python 3.14 (crypt module removed)
neg_groups:
  cmd.run:
    - name: usermod -aG wheel,libvirt,plugdev neg
    - unless: id -nG neg | tr ' ' '\n' | grep -qx plugdev
    - require:
      - group: plugdev_group

sudo_timeout:
  file.managed:
    - name: /etc/sudoers.d/timeout
    - contents: |
        Defaults timestamp_timeout=30
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

# Use rpm-ostree for Silverblue.
# Batch packages for speed and correct dependency resolution.
# Base image: Wayblue-Hyprland (ghcr.io/wayblueorg/hyprland:latest)
# Packages already in Wayblue base image (do NOT layer):
#   7zip-standalone (obsoletes p7zip), fzf, ImageMagick, inotify-tools, jq,
#   kitty, lsof, make, mtr, procps-ng, psmisc, qrencode, rust,
#   tree-sitter-cli, unzip, waybar, xz, yt-dlp, zip
# Hyprland-specific (shipped by image): hyprland, hyprland-qtutils, hyprlock,
#   hypridle, hyprpaper, xdg-desktop-portal-hyprland
# Steam + gaming tools (gamescope, mangohud, protontricks, vkBasalt) moved to
# Distrobox CachyOS container — see states/distrobox.sls
{% set categories = {
    'Archives & Compression': [
        {'name': 'lbzip2',              'desc': 'Parallel bzip2 compression utility'},
        {'name': 'patool',              'desc': 'Portable archive file manager'},
        {'name': 'pbzip2',              'desc': 'Parallel bzip2 implementation'},
        {'name': 'pigz',                'desc': 'Parallel gzip implementation'},
        {'name': 'unar',                'desc': 'Universal archive unpacker'}
    ],
    'Development': [
        {'name': 'act',                 'desc': 'Run GitHub Actions locally'},
        {'name': 'android-tools',       'desc': 'Android platform tools (adb, fastboot)'},
        {'name': 'ansible',             'desc': 'IT automation and configuration management'},
        {'name': 'bpftrace',            'desc': 'High-level eBPF tracing language'},
        {'name': 'cargo',               'desc': 'Rust package manager'},
        {'name': 'clang-libs',          'desc': 'Clang runtime libraries'},
        {'name': 'cmake',               'desc': 'Cross-platform build system'},
        {'name': 'difftastic',          'desc': 'Structural diff tool'},
        {'name': 'dbus-devel',           'desc': 'D-Bus development headers (for building Rust crates like libdbus-sys)'},
        {'name': 'direnv',              'desc': 'Per-directory shell configuration tool'},
        {'name': 'dkms',                'desc': 'Dynamic Kernel Module Support Framework'},
        {'name': 'elfutils',            'desc': 'ELF binary analysis tools'},
        {'name': 'gcc',                 'desc': 'Various compilers (C, C++, ...)'},
        {'name': 'gdb',                 'desc': 'GNU Debugger'},
        {'name': 'graphviz',            'desc': 'Graph visualization tools'},
        {'name': 'helix',               'desc': 'Post-modern modal text editor'},
        {'name': 'hexyl',               'desc': 'Hex viewer with colored output'},
        {'name': 'hxtools',             'desc': 'Misc CLI utilities and git helpers'},
        {'name': 'hyperfine',           'desc': 'Command-line benchmarking tool'},
        {'name': 'just',                'desc': 'Just a command runner'},
        {'name': 'kernel-devel',        'desc': 'Development package for building kernel modules'},
        {'name': 'lldb',                'desc': 'LLVM debugger'},
        {'name': 'openocd',             'desc': 'On-chip debugger for embedded systems'},
        {'name': 'nodejs',              'desc': 'JavaScript runtime (for npm global installs)'},
        {'name': 'npm',                 'desc': 'Node.js package manager'},
        {'name': 'perf',                'desc': 'Performance analysis tools for Linux'},
        {'name': 'pgcli',               'desc': 'PostgreSQL CLI with autocomplete'},
        {'name': 'pipewire-devel',      'desc': 'PipeWire development files'},
        {'name': 'ruff',                'desc': 'Fast Python linter and formatter'},
        {'name': 'ShellCheck',          'desc': 'Shell script analysis tool'},
        {'name': 'shfmt',               'desc': 'Shell script formatter'},
        {'name': 'strace',              'desc': 'System call tracer'},
        {'name': 'valgrind',            'desc': 'Memory debugging and profiling'},
        {'name': 'yamllint',            'desc': 'YAML linter'}
    ],
    'File Management': [
        {'name': 'bat',                 'desc': 'A cat(1) clone with wings'},
        {'name': 'borgbackup',          'desc': 'Deduplicating archiver with compression and encryption'},
        {'name': 'convmv',              'desc': 'Convert filename encodings'},
        {'name': 'ddrescue',            'desc': 'Data recovery tool for failing drives'},
        {'name': 'dos2unix',            'desc': 'Text file format converters'},
        {'name': 'du-dust',             'desc': 'More intuitive version of du'},
        {'name': 'enca',                'desc': 'Character set analyzer and converter'},
        {'name': 'fd-find',             'desc': 'Fd is a simple, fast and user-friendly alternative to find'},
        {'name': 'jdupes',              'desc': 'Duplicate file finder and remover'},
        {'name': 'ncdu',                'desc': 'Text-based disk usage viewer'},
        {'name': 'plocate',             'desc': 'Fast file locate'},
        {'name': 'ripgrep',             'desc': 'Fast regex search tool'},
        {'name': 'rclone',              'desc': 'Cloud storage sync tool'},
        {'name': 'rmlint',              'desc': 'Find space waste and other broken things on your filesystem'},
        {'name': 'testdisk',            'desc': 'Data recovery and partition repair tool'}
    ],
    'Fonts': [
        {'name': 'material-icons-fonts', 'desc': 'Material Design icons fonts'}
    ],
    'Media': [
        {'name': 'advancecomp',         'desc': 'Recompression utilities for .png, .mng, .zip, .gz'},
        {'name': 'Carla',               'desc': 'Audio plugin host (LADSPA, DSSI, LV2, VST2/3)'},
        {'name': 'beets',               'desc': 'Music library manager and tagger'},
        {'name': 'cava',                'desc': 'Console audio visualizer'},
        {'name': 'cdparanoia',          'desc': 'Secure CD ripper'},
        {'name': 'chafa',               'desc': 'Image-to-text converter for terminal'},
        {'name': 'darktable',           'desc': 'Utility to organize and develop raw images'},
        {'name': 'ffmpegthumbnailer',   'desc': 'Lightweight video thumbnailer'},
        {'name': 'helvum',              'desc': 'GTK patchbay for PipeWire'},
        {'name': 'id3v2',               'desc': 'Command-line ID3v2 tag editor'},
        {'name': 'jpegoptim',           'desc': 'Utility to optimize JPEG files'},
        {'name': 'lsp-plugins',         'desc': 'Linux Studio Plugins for audio production'},
        {'name': 'mediainfo',           'desc': 'Media file information utility'},
        {'name': 'mpd',                 'desc': 'Music Player Daemon'},
        {'name': 'mpc',                 'desc': 'Command-line MPD client'},
        {'name': 'mpdas',               'desc': 'Last.fm scrobbler for MPD'},
        {'name': 'mpdris2',             'desc': 'MPRIS2 bridge for MPD'},
        {'name': 'mpv',                 'desc': 'A free, open source, and cross-platform media player'},
        {'name': 'optipng',             'desc': 'PNG optimizer'},
        {'name': 'perl-Image-ExifTool', 'desc': 'Utility for reading and writing image meta info'},
        {'name': 'chromaprint-tools',   'desc': 'AcoustID audio fingerprint calculator (fpcalc)'},
        {'name': 'picard',              'desc': 'MusicBrainz GUI music tagger'},
        {'name': 'pngquant',            'desc': 'PNG quantization tool for lossy compression'},
        {'name': 'qpwgraph',            'desc': 'Qt PipeWire patchbay'},
        {'name': 'rawtherapee',         'desc': 'Raw image processing application'},
        {'name': 'raysession',          'desc': 'Session manager for audio production'},
        {'name': 'sonic-visualiser',    'desc': 'Audio analysis and visualization'},
        {'name': 'wiremix',             'desc': 'PipeWire terminal volume mixer'},
        {'name': 'supercollider',       'desc': 'Audio synthesis engine and programming IDE'},
        {'name': 'sox',                 'desc': 'A general purpose sound file conversion tool'},
        {'name': 'swayimg',             'desc': 'Image viewer for Sway/Wayland'},
        {'name': 'tesseract',           'desc': 'OCR engine'},
        {'name': 'zbar',                'desc': 'Bar code reader'},
        {'name': 'media-player-info',   'desc': 'udev data for media players'}
    ],
    'Monitoring & System': [
        {'name': 'atop',                'desc': 'Advanced system and process monitor'},
        {'name': 'blktrace',            'desc': 'Block layer I/O tracing tools'},
        {'name': 'btop',                'desc': 'A monitor of resources (CPU, Memory, Network)'},
        {'name': 'device-mapper-multipath', 'desc': 'Tools for managing multipath devices'},
        {'name': 'fastfetch',           'desc': 'Fast neofetch-like system information tool'},
        {'name': 'fio',                 'desc': 'Flexible I/O tester and benchmark'},
        {'name': 'gdisk',              'desc': 'GPT partition tools (sgdisk, fixparts)'},
        {'name': 'goaccess',            'desc': 'Real-time web log analyzer and interactive viewer'},
        {'name': 'hw-probe',            'desc': 'Hardware probe and diagnostics'},
        {'name': 'hwinfo',              'desc': 'Detailed hardware information tool'},
        {'name': 'inxi',                'desc': 'System information script'},
        {'name': 'ioping',              'desc': 'Simple disk I/O latency monitor'},
        {'name': 'iotop-c',             'desc': 'I/O monitoring tool'},
        {'name': 'kexec-tools',         'desc': 'Directly boot into a new kernel'},
        {'name': 'liquidctl',           'desc': 'Fan/pump/LED controller for AIO and peripherals'},
        {'name': 'lm_sensors',          'desc': 'Hardware sensor monitoring (temps, fans, voltages)'},
        {'name': 'lnav',                'desc': 'Curses-based tool for viewing and analyzing log files'},
        {'name': 'lshw',                'desc': 'Hardware lister'},
        {'name': 'memtester',           'desc': 'User-space memory stress test'},
        {'name': 'nvtop',               'desc': 'GPU process monitor'},
        {'name': 'parted',              'desc': 'GNU Partition Editor'},
        {'name': 'procdump',            'desc': 'Linux process core dump generator'},
        {'name': 'progress',            'desc': 'Coreutils Viewer'},
        {'name': 'pv',                  'desc': 'A tool for monitoring the progress of data through a pipeline'},
        {'name': 's-tui',               'desc': 'Stress terminal UI for CPU monitoring'},
        {'name': 'schedtool',           'desc': 'CPU scheduling policy control'},
        {'name': 'smartmontools',       'desc': 'S.M.A.R.T. disk monitoring tools'},
        {'name': 'sysstat',             'desc': 'Performance monitoring tools'},
        {'name': 'vmtouch',             'desc': 'Virtual memory touch / file paging tool'},
        {'name': 'vnstat',              'desc': 'Network traffic monitor'},
        {'name': 'below',               'desc': 'BPF time-traveling system monitor'},
        {'name': 'kernel-tools',        'desc': 'Kernel utilities (turbostat, cpupower)'}
    ],
    'Network': [
        {'name': 'aria2',               'desc': 'High speed download utility with resuming and segmented downloading'},
        {'name': 'fping',               'desc': 'Fast ping utility'},
        {'name': 'freerdp',             'desc': 'Remote Desktop Protocol client'},
        {'name': 'fuse-sshfs',          'desc': 'Mount remote directories over SSH'},
        {'name': 'GeoIP',               'desc': 'IP-to-location lookup library and tools'},
        {'name': 'httpie',              'desc': 'Modern command-line HTTP client'},
        {'name': 'iftop',               'desc': 'Display bandwidth usage on an interface'},
        {'name': 'iperf',               'desc': 'Network bandwidth measurement tool'},
        {'name': 'iwd',                 'desc': 'Wireless daemon for Linux'},
        {'name': 'nicotine+',           'desc': 'Soulseek P2P file sharing client'},
        {'name': 'nmap-ncat',           'desc': 'Netcat from nmap project'},
        {'name': 'ollama',              'desc': 'Local LLM runner'},
        {'name': 'prettyping',          'desc': 'Wrapper around ping to make output prettier'},
        {'name': 'sshpass',             'desc': 'Non-interactive SSH password auth'},
        {'name': 'streamlink',          'desc': 'CLI for extracting streams from websites'},
        {'name': 'telegram-desktop',    'desc': 'Telegram Desktop messaging app'},
        {'name': 'traceroute',          'desc': 'Trace packet route to host'},
        {'name': 'ttyd',               'desc': 'Share terminal over the web'},
        {'name': 'whois',               'desc': 'Domain registration information lookup'},
        {'name': 'vdirsyncer',         'desc': 'CalDAV/CardDAV synchronization tool'},
        {'name': 'transmission-gtk',    'desc': 'BitTorrent client'},
        {'name': 'w3m',                 'desc': 'Text-mode web browser'},
        {'name': 'waypipe',             'desc': 'Network transparency for Wayland'},
        {'name': 'wayvnc',              'desc': 'VNC server for Wayland'},
        {'name': 'zmap',                'desc': 'Fast internet-wide scanner'}
    ],
    'Shell & Tools': [
        {'name': 'abduco',              'desc': 'Session management in a clean and simple way'},
        {'name': 'age',                 'desc': 'Modern file encryption tool'},
        {'name': 'asciinema',           'desc': 'Terminal session recorder, streamer and player'},
        {'name': 'cowsay',              'desc': 'Talking cow ASCII art'},
        {'name': 'libnotify',           'desc': 'Desktop notification library (notify-send)'},
        {'name': 'cpufetch',            'desc': 'Simple yet fancy CPU architecture fetching tool'},
        {'name': 'dash',                'desc': 'Small and fast POSIX-compliant shell'},
        {'name': 'dcfldd',              'desc': 'Enhanced dd with hashing and status output'},
        {'name': 'entr',                'desc': 'Run arbitrary commands when files change'},
        {'name': 'expect',              'desc': 'Tool for automating interactive applications'},
        {'name': 'figlet',              'desc': 'ASCII art text banners'},
        {'name': 'fortune-mod',         'desc': 'Random quotes and aphorisms'},
        {'name': 'freeze',              'desc': 'Generate images of code and terminal output'},
        {'name': 'gh',                  'desc': 'GitHub CLI'},
        {'name': 'git-lfs',             'desc': 'Git Large File Storage'},
        {'name': 'glow',                'desc': 'Render markdown on the CLI'},
        {'name': 'gopass',              'desc': 'Password store with extensions'},
        {'name': 'jc',                  'desc': 'CLI tool to convert command output to JSON'},
        {'name': 'lolcat',              'desc': 'Rainbow-colored cat output'},
        {'name': 'lowdown',             'desc': 'Markdown translator'},
        {'name': 'miller',              'desc': 'Like awk, sed, cut, join, and sort for name-indexed data'},
        {'name': 'minicom',             'desc': 'Serial console and communication program'},
        {'name': 'moreutils',           'desc': 'Additional unix utilities'},
        {'name': 'mtools',              'desc': 'MS-DOS disk utilities'},
        {'name': 'neo',                 'desc': 'Matrix digital rain effect'},
        {'name': 'neomutt',             'desc': 'Terminal email client'},
        {'name': 'netmask',             'desc': 'IP address and netmask manipulation'},
        {'name': 'no-more-secrets',     'desc': 'Recreate the data decryption effect from Sneakers'},
        {'name': 'par',                 'desc': 'Paragraph reformatter, vaguely like fmt, but more elaborate'},
        {'name': 'parallel',            'desc': 'Shell tool for executing jobs in parallel'},
        {'name': 'pastel',              'desc': 'CLI tool to generate, analyze, convert and manipulate colors'},
        {'name': 'pwgen',               'desc': 'Automatic password generation'},
        {'name': 'recoll',              'desc': 'Desktop full-text search tool'},
        {'name': 'reptyr',              'desc': 'Attach a running process to a new terminal'},
        {'name': 'rlwrap',              'desc': 'Readline wrapper for interactive commands'},
        {'name': 'sad',                 'desc': 'CLI search and replace'},
        {'name': 'salt',                'desc': 'A parallel remote execution system'},
        {'name': 'sqlite',              'desc': 'SQLite database CLI'},
        {'name': 'tealdeer',            'desc': 'A fast tldr client in Rust'},
        {'name': 'tmux',                'desc': 'Terminal multiplexer'},
        {'name': 'toilet',              'desc': 'Color ASCII art text banners'},
        {'name': 'translate-shell',     'desc': 'Command-line online translator'},
        {'name': 'udiskie',             'desc': 'Automounter for removable media'},
        {'name': 'ugrep',              'desc': 'Ultra fast grep with interactive query UI'},
        {'name': 'urlscan',             'desc': 'Extract and browse URLs from email messages'},
        {'name': 'urlwatch',            'desc': 'Web page change monitor and notifier'},
        {'name': 'yq',                  'desc': 'YAML/XML/TOML processor'},
        {'name': 'zathura',             'desc': 'Minimal document viewer'},
        {'name': 'zathura-pdf-poppler', 'desc': 'PDF plugin for zathura'},
        {'name': 'zoxide',              'desc': 'Smarter cd command for your terminal'},
        {'name': 'zsh',                 'desc': 'Powerful interactive shell'}
    ],
    'Wayland': [
        {'name': 'cliphist',            'desc': 'Clipboard history for Wayland'},
        {'name': 'dunst',               'desc': 'Lightweight notification daemon'},
        {'name': 'pyprland',            'desc': 'Hyprland plugin system and scratchpads'},
        {'name': 'rofi',                'desc': 'Window switcher, application launcher and dmenu replacement'},
        {'name': 'screenkey',           'desc': 'Show keystrokes on screen'},
        {'name': 'swappy',              'desc': 'Screenshot annotation tool for Wayland'},
        {'name': 'swaybg',              'desc': 'Wayland background setter'},
        {'name': 'swww',                'desc': 'Animated wallpaper daemon for Wayland'},
        {'name': 'wev',                 'desc': 'Wayland event viewer for debugging'},
        {'name': 'wf-recorder',         'desc': 'Wayland screen recorder'},
        {'name': 'wlogout',             'desc': 'Wayland logout menu'},
        {'name': 'wtype',               'desc': 'xdotool type for Wayland'},
        {'name': 'ydotool',             'desc': 'Generic command-line automation tool for Wayland'}
    ],
    'Gaming & Emulation': [
        {'name': '0ad',                 'desc': 'Ancient warfare real-time strategy game'},
        {'name': 'abuse',               'desc': 'Action platformer game'},
        {'name': 'angband',             'desc': 'Classic Tolkien-themed roguelike'},
        {'name': 'crawl-tiles',         'desc': 'Dungeon Crawl Stone Soup with tiles'},
        {'name': 'dosbox-staging',      'desc': 'Modernized DOSBox fork'},
        {'name': 'endless-sky',         'desc': 'Space exploration and trading game'},
        {'name': 'fheroes2',            'desc': 'Free Heroes of Might and Magic II engine'},
        {'name': 'flare',               'desc': 'Free Libre Action Roleplaying Engine'},
        {'name': 'gnuchess',            'desc': 'GNU Chess engine'},
        {'name': 'nethack',             'desc': 'Classic roguelike adventure game'},
        {'name': 'openmw',              'desc': 'Open-source Morrowind engine reimplementation'},
        {'name': 'retroarch',           'desc': 'Multi-platform emulator frontend'},
        {'name': 'supertux',            'desc': '2D platformer inspired by Super Mario'},
        {'name': 'wesnoth',             'desc': 'Turn-based strategy game'},
        {'name': 'xaos',                'desc': 'Interactive fractal zoomer'},
        {'name': 'xonotic',             'desc': 'Fast-paced FPS game'}
    ],
    'Security': [
        {'name': 'hashcat',             'desc': 'Advanced password recovery tool'},
        {'name': 'pcsc-tools',          'desc': 'Smartcard reader debugging tools'},
        {'name': 'tcpdump',             'desc': 'Network packet analyzer'},
        {'name': 'wireshark-cli',       'desc': 'Network protocol analyzer CLI (tshark)'}
    ],
    'Virtualization': [
        {'name': 'bottles',             'desc': 'Wine/Proton application manager'},
        {'name': 'libvirt-daemon-config-network', 'desc': 'Libvirt default NAT network config'},
        {'name': 'qemu-kvm',            'desc': 'QEMU/KVM virtual machine emulator'},
        {'name': 'virt-manager',        'desc': 'Virtual machine manager GUI'}
    ],
    'Desktop': [
        {'name': 'corectrl',            'desc': 'AMD GPU power and fan control'},
        {'name': 'ddccontrol',          'desc': 'DDC monitor control'},
        {'name': 'hunspell-ru',         'desc': 'Russian dictionary for spellchecking'},
        {'name': 'nuspell',             'desc': 'Modern spellchecker library and CLI'},
        {'name': 'kvantum',             'desc': 'SVG-based Qt theme engine'},
        {'name': 'openrgb',             'desc': 'Peripheral RGB LED controller'},
        {'name': 'qt5ct',               'desc': 'Qt5 configuration tool'},
        {'name': 'texlive-scheme-basic', 'desc': 'TeX Live basic scheme'}
    ],
    'Version Control': [
        {'name': 'chezmoi',             'desc': 'Manage your dotfiles across multiple diverse machines'},
        {'name': 'diff-so-fancy',       'desc': 'Good-looking diffs with diff-highlight and more'},
        {'name': 'etckeeper',           'desc': 'Store /etc in a git repository'},
        {'name': 'git',                 'desc': 'Fast Version Control System'},
        {'name': 'git-crypt',           'desc': 'Transparent file encryption in git'},
        {'name': 'git-delta',           'desc': 'Syntax-highlighting pager for git'},
        {'name': 'git-extras',          'desc': 'Extra git commands for everyday use'},
        {'name': 'onefetch',            'desc': 'Git repository summary on your terminal'},
        {'name': 'tig',                 'desc': 'Text-mode interface for the git revision control system'}
    ]
} %}

{# Laptop-only packages: battery info, power analysis #}
{% if host.is_laptop %}
{% do categories['Monitoring & System'].extend([
    {'name': 'acpi',     'desc': 'ACPI battery and thermal info'},
    {'name': 'powertop', 'desc': 'Power consumption analyzer'},
]) %}
{% endif %}

{% set copr_packages = [
    {'name': 'dualsensectl',                'desc': 'DualSense controller LED/haptics control'},
    {'name': 'espanso-wayland',             'desc': 'Cross-platform text expander (Wayland build)'},
    {'name': 'himalaya',                    'desc': 'CLI email client using JMAP/IMAP'},
    {'name': 'spotifyd',                    'desc': 'Lightweight Spotify Connect daemon'},
    {'name': 'sbctl',                       'desc': 'Secure Boot key manager'},
    {'name': 'brutefir',                    'desc': 'Software convolution audio engine'},
    {'name': 'patchmatrix',                 'desc': 'JACK patchbay in flow matrix form'},
    {'name': 'supercollider-sc3-plugins',   'desc': 'Community UGen plugins for SuperCollider'},
] %}
{# '86Box' removed — needs Qt 6.10, base image pins 6.9.2 #}

include:
  - pkg_cache
  - amnezia
  - bind_mounts
  - build_rpms
  - distrobox
  - dns
  - fira-code-nerd
  - hardware
  - hy3
  - install_rpms
  - kernel_modules
  - kernel_params
  - monitoring
  - mpd
  - network
  - services
  - sysctl

# Remove packages no longer in desired state.
# rpm-ostree only adds, never removes — this handles cleanup explicitly.
{# unwanted_packages rationale:
   - nnn/ranger/stow/axel/speedtest-cli/pcem: replaced by better alternatives
   - python3-devel etc.: orphan build deps no longer needed at runtime
   - pass: replaced by gopass
   - *-debug{info,source}: debug packages from custom RPM builds
   - alacritty/foot/g++: replaced terminals / unused compiler
   - nethogs: replaced by bandwhich (custom RPM)
   - steam etc.: moved to Distrobox CachyOS container
#}
{% set unwanted_packages = [
    'nnn', 'ranger', 'stow', 'axel', 'speedtest-cli', 'pcem', 'nethogs',
    'python3-devel', 'ncurses-devel', 'pulseaudio-libs-devel', 'taglib-devel',
    'pass',
    'albumdetails-debuginfo', 'albumdetails-debugsource',
    'amneziawg-tools-debuginfo', 'amneziawg-tools-debugsource',
    'alacritty', 'foot', 'g++',
    'steam', 'gamescope', 'mangohud', 'protontricks', 'python3-vkbasalt-cli', 'vkBasalt',
] %}
remove_unwanted_packages:
  cmd.run:
    - name: |
        {% raw %}
        to_remove=()
        pkgs=({% endraw %}{% for pkg in unwanted_packages %}'{{ pkg }}' {% endfor %}{% raw %})
        for pkg in "${pkgs[@]}"; do
          rpm -q "$pkg" > /dev/null 2>&1 && to_remove+=("$pkg")
        done
        if [ ${#to_remove[@]} -gt 0 ]; then
          echo "Removing: ${to_remove[*]}"
          rpm-ostree uninstall "${to_remove[@]}" || true
        fi
        {% endraw %}
    - onlyif: rpm -q {% for pkg in unwanted_packages %}{{ pkg }} {% endfor %}2>/dev/null | grep -v 'not installed'

# Install all packages (system + COPR) in a single rpm-ostree transaction.
# One transaction = one deployment, much faster than two separate ones.
install_all_packages:
  cmd.run:
    - name: |
        {% raw %}
        wanted=({% endraw %}{% for cat, pkgs in categories | dictsort %}{% for pkg in pkgs %}{{ pkg.name }} {% endfor %}{% endfor %}{% for pkg in copr_packages %}{{ pkg.name }} {% endfor %}{% raw %})
        installed=$(rpm -qa --queryformat '%{NAME}\n' | sort -u)
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-packages"[]?' | sort -u)
        have=$(sort -u <(echo "$installed") <(echo "$layered"))
        missing=$(comm -23 <(printf '%s\n' "${wanted[@]}" | sort -u) <(echo "$have"))
        if [ -n "$missing" ]; then
          rpm-ostree install -y --allow-inactive $missing
        fi
        {% endraw %}
    - unless: rpm -q {% for cat, pkgs in categories | dictsort %}{% for pkg in pkgs %}{{ pkg.name }} {% endfor %}{% endfor %}{% for pkg in copr_packages %}{{ pkg.name }} {% endfor %}> /dev/null 2>&1
    - require:
      - file: fix_containers_policy
      - cmd: copr_dualsensectl
      - cmd: copr_espanso
      - cmd: copr_himalaya
      - cmd: copr_spotifyd
      - cmd: copr_sbctl
      - cmd: copr_audinux
      - cmd: rpmfusion_nonfree
      {# - cmd: copr_86box -- disabled, 86Box needs Qt 6.10 #}

zsh_config_dir:
  file.directory:
    - name: /etc/zsh
    - user: root
    - group: root
    - mode: '0755'

/etc/zshenv:
  file.managed:
    - contents: |
        # System-wide Zsh environment
        export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    - user: root
    - group: root
    - mode: '0644'

/etc/zsh/zshrc:
  file.managed:
    - contents: |
        # System-wide zshrc
        # If ZDOTDIR is set, zsh will source it from there.
        # This ensures ZDOTDIR is respected even if set in /etc/zshenv
        [[ -f "$ZDOTDIR/.zshrc" ]] && source "$ZDOTDIR/.zshrc"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

# Force shell update for users (rpm-ostree might be tricky with user.present)
force_zsh_neg:
  cmd.run:
    - name: usermod -s /usr/bin/zsh neg
    - unless: 'test "$(getent passwd neg | cut -d: -f7)" = "/usr/bin/zsh"'

force_zsh_root:
  cmd.run:
    - name: usermod -s /usr/bin/zsh root
    - unless: 'test "$(getent passwd root | cut -d: -f7)" = "/usr/bin/zsh"'

etckeeper_init:
  cmd.run:
    - name: etckeeper init && etckeeper commit "Initial commit"
    - unless: test -d /etc/.git
    - onlyif: command -v etckeeper

running_services:
  service.running:
    - names:
      - NetworkManager
      - firewalld
      - chronyd
      - dbus-broker
      - bluetooth
      - libvirtd
      - openrgb
    - enable: True

# Disable tuned: its throughput-performance profile conflicts with custom
# I/O tuning (sets read_ahead_kb=8192 on NVMe, may override sysctl values).
# All tuning is managed manually via sysctl.sls, kernel_params.sls, hardware.sls.
disable_tuned:
  service.dead:
    - name: tuned
    - enable: False

# --- greetd: replace sddm with quickshell greeter ---
disable_sddm:
  service.dead:
    - name: sddm
    - enable: False

greetd_config_dir:
  file.directory:
    - name: /etc/greetd
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

greetd_config:
  file.managed:
    - name: /etc/greetd/config.toml
    - contents: |
        [terminal]
        vt = 1

        [default_session]
        command = "Hyprland -c /etc/greetd/hyprland-greeter.conf"
        user = "neg"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_hyprland_config:
  file.managed:
    - name: /etc/greetd/hyprland-greeter.conf
    - contents: |
        # Monitor: match main session resolution
        {% if host.display %}
        monitorv2 {
            output = DP-2
            mode = {{ host.display }}
            position = 0x0
            scale = 2
            vrr = 3
            bitdepth = 10
        }
        monitorv2 {
            output = DP-1
            disabled = true
        }
        experimental {
            xx_color_management_v4 = true
        }
        {% endif %}

        misc {
            force_default_wallpaper = 0
            disable_hyprland_logo = true
        }

        # Cursor: match main session theme
        env = XCURSOR_THEME,Alkano-aio
        env = XCURSOR_SIZE,23
        env = HYPRCURSOR_THEME,Alkano-aio
        env = HYPRCURSOR_SIZE,23
        cursor {
            sync_gsettings_theme = true
        }

        exec-once = qs -p ~/.config/quickshell/greeter/greeter.qml
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_session_wrapper:
  file.managed:
    - name: /etc/greetd/session-wrapper
    - contents: |
        #!/bin/sh
        [ -f /etc/profile ] && . /etc/profile
        set -a
        [ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
        set +a
        exec /usr/bin/starthyprland
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: greetd_config_dir

greetd_wallpaper:
  cmd.run:
    - name: |
        wallpaper=$(tr '\0' '\n' < /var/home/neg/.cache/swww/DP-2 2>/dev/null | grep '^/')
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
          cp -f "$wallpaper" /var/home/neg/.cache/greeter-wallpaper
        fi
    - runas: neg
    - require:
      - file: greetd_config_dir

# SELinux: allow greeter (xdm_t) to mmap fontconfig cache and read wallpaper from user cache
greetd_selinux_cache:
  cmd.run:
    - name: |
        TMP=$(mktemp -d)
        cat > "$TMP/greetd-cache.te" << 'POLICY'
        module greetd-cache 1.0;
        require {
            type xdm_t;
            type cache_home_t;
            type user_fonts_cache_t;
            class file { read open getattr map };
        }
        allow xdm_t user_fonts_cache_t:file map;
        allow xdm_t cache_home_t:file { read open getattr map };
        POLICY
        checkmodule -M -m -o "$TMP/greetd-cache.mod" "$TMP/greetd-cache.te"
        semodule_package -o "$TMP/greetd-cache.pp" -m "$TMP/greetd-cache.mod"
        semodule -i "$TMP/greetd-cache.pp"
        rm -rf "$TMP"
    - unless: semodule -l | grep -q '^greetd-cache'

greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_config
      - cmd: install_custom_rpms

/mnt/zero:
  file.directory:
    - makedirs: True

mount_zero:
  mount.mounted:
    - name: /mnt/zero
    - device: /dev/mapper/argon-zero
    - fstype: xfs
    - mkmnt: True
    - opts: noatime
    - persist: True

/mnt/one:
  file.directory:
    - makedirs: True

mount_one:
  mount.mounted:
    - name: /mnt/one
    - device: /dev/mapper/xenon-one
    - fstype: xfs
    - mkmnt: True
    - opts: noatime
    - persist: True

# btrfs compression: set as filesystem property since Fedora Atomic's ostree
# mount mechanism ignores compress= fstab option (not shown in /proc/mounts).
btrfs_compress_home:
  cmd.run:
    - name: btrfs property set /var/home compression zstd:-1
    - unless: btrfs property get /var/home compression 2>/dev/null | grep -q 'zstd:-1'

btrfs_compress_var:
  cmd.run:
    - name: btrfs property set /var compression zstd:-1
    - unless: btrfs property get /var compression 2>/dev/null | grep -q 'zstd:-1'

# Flatpak applications
{% set flatpak_apps = [
    {'id': 'net.pcsx2.PCSX2',                          'desc': 'PlayStation 2 emulator'},
    {'id': 'net.davidotek.pupgui2',                     'desc': 'ProtonUp-Qt — Proton/Wine-GE version manager'},
    {'id': 'io.github.dimtpap.coppwr',                  'desc': 'PipeWire graph inspector'},
    {'id': 'com.github.tmewett.BrogueCE',               'desc': 'Community edition of Brogue roguelike'},
    {'id': 'org.zdoom.GZDoom',                           'desc': 'Advanced Doom source port'},
    {'id': 'tk.deat.Jazz2Resurrection',                  'desc': 'Jazz Jackrabbit 2 reimplementation'},
    {'id': 'net.veloren.airshipper',                     'desc': 'Veloren voxel RPG launcher'},
    {'id': 'com.shatteredpixel.shatteredpixeldungeon',   'desc': 'Roguelike dungeon crawler'},
    {'id': 'one.ablaze.floorp',                          'desc': 'Privacy-focused Firefox fork'},
    {'id': 'me.timschneeberger.jdsp4linux',              'desc': 'JamesDSP audio effects for Linux'},
    {'id': 'com.vysp3r.ProtonPlus',                      'desc': 'Proton/Wine compatibility tool manager'},
    {'id': 'com.obsproject.Studio',                      'desc': 'OBS Studio — streaming and recording'},
    {'id': 'net.sapples.LiveCaptions',                   'desc': 'Real-time speech-to-text captions'},
    {'id': 'md.obsidian.Obsidian',                       'desc': 'Markdown knowledge base'},
    {'id': 'org.chromium.Chromium',                      'desc': 'Open-source Chromium browser'},
    {'id': 'org.gimp.GIMP',                              'desc': 'GNU Image Manipulation Program'},
    {'id': 'com.google.Chrome',                          'desc': 'Google Chrome browser'},
    {'id': 'org.libreoffice.LibreOffice',                'desc': 'Office suite'},
    {'id': 'net.lutris.Lutris',                          'desc': 'Gaming platform for Linux'},
    {'id': 'com.github.qarmin.czkawka',                  'desc': 'Duplicate file and image finder'},
    {'id': 'com.google.AndroidStudio',                   'desc': 'Android IDE'},
    {'id': 'io.github.woelper.Oculante',                 'desc': 'Fast image viewer with editing'},
] %}

install_flatpak_apps:
  cmd.run:
    - name: |
        installed=$(flatpak list --user --app --columns=application)
        apps=({% for app in flatpak_apps %}'{{ app.id }}' {% endfor %})
        missing=()
        for app in "${apps[@]}"; do
          grep -qxF "$app" <<< "$installed" || missing+=("$app")
        done
        if [ -n "${missing[*]}" ]; then
          flatpak install --user -y flathub "${missing[@]}"
        fi
    - runas: neg
    - unless: |
        installed=$(flatpak list --user --app --columns=application)
        apps=({% for app in flatpak_apps %}'{{ app.id }}' {% endfor %})
        for app in "${apps[@]}"; do
          grep -qxF "$app" <<< "$installed" || exit 1
        done

# Flatpak overrides: Wayland cursor + GTK dark theme
flatpak_overrides:
  cmd.run:
    - name: flatpak override --user --env=XCURSOR_PATH=/run/host/user-share/icons:/run/host/share/icons --env=GTK_THEME=Adwaita:dark
    - runas: neg
    - require:
      - cmd: install_flatpak_apps
    - unless: flatpak override --user --show 2>/dev/null | grep -q XCURSOR_PATH

# --- Floorp browser: user.js + userChrome.css + userContent.css ---
floorp_user_js:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/user.js
    - source: salt://dotfiles/dot_config/floorp/user.js
    - user: neg
    - group: neg
    - makedirs: True

floorp_userchrome:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/chrome/userChrome.css
    - source: salt://dotfiles/dot_config/floorp/userChrome.css
    - user: neg
    - group: neg
    - makedirs: True

floorp_usercontent:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/chrome/userContent.css
    - source: salt://dotfiles/dot_config/floorp/userContent.css
    - user: neg
    - group: neg
    - makedirs: True

# --- Floorp extensions (download .xpi into profile) ---
{% set floorp_profile = '/var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default' %}
{% set floorp_extensions = [
    {'id': '{a8332c60-5b6d-41ee-bfc8-e9bb331d34ad}',         'slug': 'surfingkeys_ff'},
    {'id': 'uBlock0@raymondhill.net',                         'slug': 'ublock-origin'},
    {'id': 'addon@darkreader.org',                            'slug': 'darkreader'},
    {'id': 'sponsorBlocker@ajay.app',                         'slug': 'sponsorblock'},
    {'id': '{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}',         'slug': 'styl-us'},
    {'id': '{aecec67f-0d10-4fa7-b7c7-609a2db280cf}',         'slug': 'violentmonkey'},
    {'id': '{531906d3-e22f-4a6c-a102-8057b88a1a63}',         'slug': 'single-file'},
    {'id': 'addon@fastforward.team',                          'slug': 'fastforwardteam'},
    {'id': 'hide-scrollbars@qashto',                          'slug': 'hide-scrollbars'},
    {'id': 'kellyc-show-youtube-dislikes@nradiowave',         'slug': 'return-youtube-dislikes'},
    {'id': '{4a311e5c-1ccc-49b7-9c23-3e2b47b6c6d5}',         'slug': 'скачать-музыку-с-вк-vkd'},
    {'id': 'BetterDark@neopolitan.uk',                       'slug': 'betterdark'},
    {'id': 'chrome-mask@overengineer.dev',                    'slug': 'chrome-mask'},
    {'id': '{036a55b4-5e72-4d05-a06c-cba2dfcc134a}',         'slug': 'traduzir-paginas-web'},
    {'id': 'firefox-extension@steamdb.info',                  'slug': 'steam-database'},
    {'id': '{a8cf72f7-09b7-4cd4-9aaa-7a023bf09916}',         'slug': 'besttimetracker'},

    {'id': '{52bda3fd-dc48-4b3d-a7b9-58af57879f1e}',         'slug': 'stylebot-web'},
    {'id': '{1be309c5-3e4f-4b99-927d-bb500eb4fa88}',         'slug': 'augmented-steam'},
    {'id': '{d07ccf11-c0cd-4938-a265-2a4d6ad01189}',         'slug': 'view-page-archive'},
    {'id': 'extension@tabliss.io',                            'slug': 'tabliss'},
    {'id': 'firefox@ghostery.com',                            'slug': 'ghostery'},
    {'id': '{74145f27-f039-47ce-a470-a662b129930a}',         'slug': 'clearurls'},
    {'id': 'jid1-93WyvpgvxzGATw@jetpack',                    'slug': 'to-google-translate'},
    {'id': 'ATBC@EasonWong',                                  'slug': 'adaptive-tab-bar-colour'},
    {'id': 'BeautifulPurpleSky@Godie',                         'slug': 'beautiful-purple-sky'},
] %}

{% for ext in floorp_extensions %}
floorp_ext_{{ ext.slug | replace('-', '_') }}:
  cmd.run:
    - name: curl -fsSL -o '{{ floorp_profile }}/extensions/{{ ext.id }}.xpi' 'https://addons.mozilla.org/firefox/downloads/latest/{{ ext.slug }}/latest.xpi'
    - creates: {{ floorp_profile }}/extensions/{{ ext.id }}.xpi
    - runas: neg
    - require:
      - cmd: install_flatpak_apps
{% endfor %}

# Remove extensions no longer wanted.
{# unwanted: sidebery #}
{% set unwanted_extensions = [
    '{3c078156-979c-498b-8990-85f7987dd929}',
] %}

{% for ext_id in unwanted_extensions %}
floorp_remove_ext_{{ loop.index }}:
  file.absent:
    - name: {{ floorp_profile }}/extensions/{{ ext_id }}.xpi
{% endfor %}

# Remove extensions.json so Floorp rebuilds it on next launch,
# picking up extensions.autoDisableScopes=0 from user.js
floorp_reset_extensions_json:
  file.absent:
    - name: {{ floorp_profile }}/extensions.json
    - require:
      - file: floorp_user_js
{% for ext in floorp_extensions %}
      - cmd: floorp_ext_{{ ext.slug | replace('-', '_') }}
{% endfor %}

# --- Neovim Python dependencies (nvr + pynvim) ---
install_neovim_python_deps:
  cmd.run:
    - name: pip install --user pynvim neovim-remote
    - runas: neg
    - creates: /var/home/neg/.local/bin/nvr

install_zi:
  cmd.run:
    - name: |
        export ZI_HOME="$HOME/.config/zi"
        mkdir -p "$ZI_HOME"
        git clone https://github.com/z-shell/zi.git "$ZI_HOME/bin"
    - runas: neg
    - creates: /var/home/neg/.config/zi/bin/zi.zsh

install_oh_my_posh:
  cmd.run:
    - name: curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    - runas: neg
    - creates: /var/home/neg/.local/bin/oh-my-posh

install_aliae:
  cmd.run:
    - name: curl -fsSL https://github.com/JanDeDobbeleer/aliae/releases/latest/download/aliae-linux-amd64 -o ~/.local/bin/aliae && chmod +x ~/.local/bin/aliae
    - runas: neg
    - creates: /var/home/neg/.local/bin/aliae

install_grimblast:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/hyprwm/contrib/main/grimblast/grimblast -o ~/.local/bin/grimblast && chmod +x ~/.local/bin/grimblast
    - runas: neg
    - creates: /var/home/neg/.local/bin/grimblast

install_hyprevents:
  cmd.run:
    - name: |
        set -eo pipefail
        tmpdir=$(mktemp -d)
        cd "$tmpdir"
        curl -fsSL https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz | tar xz --strip-components=1
        install -Dm755 hyprevents event_handler event_loader -t ~/.local/bin/
        rm -rf "$tmpdir"
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/hyprevents

install_hyprprop:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/vilari-mickopf/hyprprop/master/hyprprop -o ~/.local/bin/hyprprop && chmod +x ~/.local/bin/hyprprop
    - runas: neg
    - creates: /var/home/neg/.local/bin/hyprprop

install_sops:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsS -o /dev/null -w '%{redirect_url}' https://github.com/getsops/sops/releases/latest | sed 's|.*/tag/||')
        curl -fsSL "https://github.com/getsops/sops/releases/download/${TAG}/sops-${TAG}.linux.amd64" -o ~/.local/bin/sops
        chmod +x ~/.local/bin/sops
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/sops

install_xdg_ninja:
  cmd.run:
    - name: curl -fsSL https://github.com/b3nj5m1n/xdg-ninja/releases/latest/download/xdgnj -o ~/.local/bin/xdg-ninja && chmod +x ~/.local/bin/xdg-ninja
    - runas: neg
    - creates: /var/home/neg/.local/bin/xdg-ninja

install_rmpc:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsS -o /dev/null -w '%{redirect_url}' https://github.com/mierak/rmpc/releases/latest | sed 's|.*/tag/||')
        curl -fsSL "https://github.com/mierak/rmpc/releases/download/${TAG}/rmpc-${TAG}-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/rmpc.tar.gz
        tar -xzf /tmp/rmpc.tar.gz -C /tmp rmpc
        mv /tmp/rmpc ~/.local/bin/
        rm -f /tmp/rmpc.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/rmpc

install_rustmission:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/intuis/rustmission/releases/download/v0.5.0/rustmission-x86_64-unknown-linux-gnu.tar.xz -o /tmp/rustmission.tar.xz
        tar -xJf /tmp/rustmission.tar.xz -C /tmp --strip-components=1 --wildcards '*/rustmission'
        mv /tmp/rustmission ~/.local/bin/
        rm -f /tmp/rustmission.tar.xz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/rustmission

install_httpstat:
  cmd.run:
    - name: pip install --user httpstat
    - runas: neg
    - creates: /var/home/neg/.local/bin/httpstat

install_ssh_to_age:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/Mic92/ssh-to-age/releases/latest/download/ssh-to-age.linux-amd64 -o ~/.local/bin/ssh-to-age
        chmod +x ~/.local/bin/ssh-to-age
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/ssh-to-age

# --- COPR repo enables (fast test -f guards) ---
copr_dualsensectl:
  cmd.run:
    - name: dnf copr enable -y kapsh/dualsensectl
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:kapsh:dualsensectl.repo

{# Kernel variant from host_config: 'lto' → kernel-cachyos-lto, 'gcc' → kernel-cachyos #}
{% set _kvar = host.features.kernel.variant %}
{% set _kcopr = 'kernel-cachyos-lto' if _kvar == 'lto' else 'kernel-cachyos' %}
{% set _kpkg  = 'kernel-cachyos-lto' if _kvar == 'lto' else 'kernel-cachyos' %}

copr_cachyos_kernel:
  cmd.run:
    - name: dnf copr enable -y bieszczaders/{{ _kcopr }}
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:{{ _kcopr }}.repo

copr_espanso:
  cmd.run:
    - name: dnf copr enable -y eclipseo/espanso
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:eclipseo:espanso.repo

copr_himalaya:
  cmd.run:
    - name: dnf copr enable -y atim/himalaya
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:atim:himalaya.repo

copr_spotifyd:
  cmd.run:
    - name: dnf copr enable -y mbooth/spotifyd
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:mbooth:spotifyd.repo

copr_sbctl:
  cmd.run:
    - name: dnf copr enable -y chenxiaolong/sbctl
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:chenxiaolong:sbctl.repo

copr_yabridge:
  cmd.run:
    - name: dnf copr enable -y patrickl/wine-tkg
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:patrickl:wine-tkg.repo

copr_audinux:
  cmd.run:
    - name: dnf copr enable -y ycollet/audinux
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ycollet:audinux.repo

# --- RPM Fusion (nonfree — for Steam; pulls in free as dependency) ---
rpmfusion_nonfree:
  cmd.run:
    - name: dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    - unless: test -f /etc/yum.repos.d/rpmfusion-nonfree.repo

{# copr_86box: disabled, 86Box needs Qt 6.10 but base image pins 6.9.2
copr_86box:
  cmd.run:
    - name: dnf copr enable -y rob72/86Box
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:rob72:86Box.repo
#}

# --- CachyOS kernel (special: override remove + install, stays separate) ---
install_cachyos_kernel:
  cmd.run:
    - name: rpm-ostree override remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra --install {{ _kpkg }} --install {{ _kpkg }}-devel-matched
    - require:
      - cmd: copr_cachyos_kernel
    - unless: rpm -q {{ _kpkg }} || rpm-ostree status --json | grep -q {{ _kpkg }}

install_yazi:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip -o /tmp/yazi.zip
        unzip -o /tmp/yazi.zip -d /tmp/yazi_extracted
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/ya ~/.local/bin/
        rm -rf /tmp/yazi.zip /tmp/yazi_extracted
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/yazi

install_broot:
  cmd.run:
    - name: curl -fsSL https://dystroy.org/broot/download/x86_64-linux/broot -o ~/.local/bin/broot && chmod +x ~/.local/bin/broot
    - runas: neg
    - creates: /var/home/neg/.local/bin/broot

install_nushell:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/nushell/nushell/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/nushell/nushell/releases/latest/download/nu-${TAG}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/nu.tar.gz
        tar -xzf /tmp/nu.tar.gz -C /tmp
        mv /tmp/nu-*-x86_64-unknown-linux-musl/nu* ~/.local/bin/
        rm -rf /tmp/nu.tar.gz /tmp/nu-*-x86_64-unknown-linux-musl
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/nu

install_eza:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz -o /tmp/eza.tar.gz
        tar -xzf /tmp/eza.tar.gz -C /tmp
        mv /tmp/eza ~/.local/bin/
        rm /tmp/eza.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/eza

install_television:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/alexpasmantier/television/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/alexpasmantier/television/releases/download/${TAG}/tv-${TAG}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/tv.tar.gz
        tar -xzf /tmp/tv.tar.gz -C /tmp
        mv /tmp/tv-${TAG}-x86_64-unknown-linux-musl/tv ~/.local/bin/
        rm -rf /tmp/tv.tar.gz /tmp/tv-${TAG}-x86_64-unknown-linux-musl
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/tv

# --- GitHub binary downloads (remaining migration packages) ---
install_xray:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
        unzip -o /tmp/xray.zip -d /tmp/xray
        mv /tmp/xray/xray ~/.local/bin/
        chmod +x ~/.local/bin/xray
        rm -rf /tmp/xray.zip /tmp/xray
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/xray

install_sing_box:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
        VER=${TAG#v}
        curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/${TAG}/sing-box-${VER}-linux-amd64.tar.gz" -o /tmp/sing-box.tar.gz
        tar -xzf /tmp/sing-box.tar.gz -C /tmp
        mv /tmp/sing-box-${VER}-linux-amd64/sing-box ~/.local/bin/
        rm -rf /tmp/sing-box.tar.gz /tmp/sing-box-${VER}-linux-amd64
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/sing-box

install_tdl:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/iyear/tdl/releases/latest/download/tdl_Linux_64bit.tar.gz -o /tmp/tdl.tar.gz
        tar -xzf /tmp/tdl.tar.gz -C /tmp tdl
        mv /tmp/tdl ~/.local/bin/
        rm -f /tmp/tdl.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/tdl

install_camilladsp:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/HEnquist/camilladsp/releases/latest/download/camilladsp-linux-amd64.tar.gz -o /tmp/camilladsp.tar.gz
        tar -xzf /tmp/camilladsp.tar.gz -C /tmp
        mv /tmp/camilladsp ~/.local/bin/
        rm -f /tmp/camilladsp.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/camilladsp

install_opencode:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/opencode-ai/opencode/releases/latest/download/opencode-linux-x86_64.tar.gz -o /tmp/opencode.tar.gz
        tar -xzf /tmp/opencode.tar.gz -C /tmp opencode
        mv /tmp/opencode ~/.local/bin/
        rm -f /tmp/opencode.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/opencode

install_adguardian:
  cmd.run:
    - name: curl -fsSL https://github.com/Lissy93/AdGuardian-Term/releases/latest/download/adguardian-linux -o ~/.local/bin/adguardian && chmod +x ~/.local/bin/adguardian
    - runas: neg
    - creates: /var/home/neg/.local/bin/adguardian

install_realesrgan:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL "https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases/download/v0.2.0/realesrgan-ncnn-vulkan-v0.2.0-ubuntu.zip" -o /tmp/realesrgan.zip
        unzip -o /tmp/realesrgan.zip -d /tmp/realesrgan
        mv /tmp/realesrgan/realesrgan-ncnn-vulkan-v0.2.0-ubuntu/realesrgan-ncnn-vulkan ~/.local/bin/
        chmod +x ~/.local/bin/realesrgan-ncnn-vulkan
        rm -rf /tmp/realesrgan.zip /tmp/realesrgan
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/realesrgan-ncnn-vulkan

install_essentia_extractor:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://data.metabrainz.org/pub/musicbrainz/acousticbrainz/extractors/essentia-extractor-v2.1_beta2-linux-x86_64.tar.gz -o /tmp/essentia.tar.gz
        tar -xzf /tmp/essentia.tar.gz -C /tmp
        mv /tmp/streaming_extractor_music ~/.local/bin/essentia_streaming_extractor_music
        chmod +x ~/.local/bin/essentia_streaming_extractor_music
        rm -rf /tmp/essentia.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/essentia_streaming_extractor_music

# --- pip installs ---
install_scdl:
  cmd.run:
    - name: pip install --user scdl
    - runas: neg
    - creates: /var/home/neg/.local/bin/scdl

install_dr14_tmeter:
  cmd.run:
    - name: pip install --user git+https://github.com/simon-r/dr14_t.meter.git
    - runas: neg
    - creates: /var/home/neg/.local/bin/dr14_tmeter

# --- cargo installs ---
install_handlr:
  cmd.run:
    - name: cargo install handlr-regex
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/handlr

install_agg:
  cmd.run:
    - name: cargo install --git https://github.com/asciinema/agg
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/agg

# NOTE: tailray needs dbus-devel (libdbus-sys). May fail on first run
# if dbus-devel was just layered and not yet active (requires reboot).
install_tailray:
  cmd.run:
    - name: cargo install --git https://github.com/NotAShelf/tailray
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/tailray
    - onlyif:
      - pkg-config --exists dbus-1
      - command -v cargo

install_pzip:
  cmd.run:
    - name: cargo install pzip
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/pz

# --- Script and file installs ---
install_mpvc:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/lwilletts/mpvc/master/mpvc -o ~/.local/bin/mpvc && chmod +x ~/.local/bin/mpvc
    - runas: neg
    - creates: /var/home/neg/.local/bin/mpvc

install_rofi_systemd:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/IvanMalison/rofi-systemd/master/rofi-systemd -o ~/.local/bin/rofi-systemd && chmod +x ~/.local/bin/rofi-systemd
    - runas: neg
    - creates: /var/home/neg/.local/bin/rofi-systemd

install_dool:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/scottchiefbaker/dool.git /tmp/dool
        cp /tmp/dool/dool ~/.local/bin/
        chmod +x ~/.local/bin/dool
        rm -rf /tmp/dool
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/dool

install_qmk_udev_rules:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules -o /etc/udev/rules.d/50-qmk.rules && udevadm control --reload-rules
    - creates: /etc/udev/rules.d/50-qmk.rules

install_oldschool_pc_fonts:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/share/fonts/oldschool-pc
        curl -fsSL https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_linux.zip -o /tmp/fonts.zip
        unzip -o /tmp/fonts.zip -d /tmp/oldschool-fonts
        find /tmp/oldschool-fonts -name '*.otf' -exec cp {} ~/.local/share/fonts/oldschool-pc/ \;
        fc-cache -f ~/.local/share/fonts/oldschool-pc/
        rm -rf /tmp/fonts.zip /tmp/oldschool-fonts
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/fonts/oldschool-pc

# --- Special: RoomEQ Wizard (Java acoustic measurement) ---
install_roomeqwizard:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/roomeqwizard
        curl -fsSL 'https://www.roomeqwizard.com/installers/REW_linux_no_jre_5_33.zip' -o /tmp/rew.zip
        unzip -o /tmp/rew.zip -d ~/.local/opt/roomeqwizard
        rm -f /tmp/rew.zip
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/opt/roomeqwizard

# --- Throne (sing-box GUI proxy frontend, bundled Qt) ---
install_throne:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/throne
        curl -fsSL https://github.com/throneproj/Throne/releases/download/1.0.13/Throne-1.0.13-linux-amd64.zip -o /tmp/throne.zip
        unzip -o /tmp/throne.zip -d ~/.local/opt/throne
        ln -sf ~/.local/opt/throne/Throne ~/.local/bin/throne
        rm -f /tmp/throne.zip
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/opt/throne

# --- Overskride (Bluetooth GTK4 client, Flatpak bundle from GitHub) ---
install_overskride:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/kaii-lb/overskride/releases/download/v0.6.6/overskride.flatpak -o /tmp/overskride.flatpak
        flatpak install --user -y /tmp/overskride.flatpak
        rm -f /tmp/overskride.flatpak
    - runas: neg
    - shell: /bin/bash
    - unless: flatpak info io.github.kaii_lb.Overskride &>/dev/null

# --- Nyxt browser (Electron AppImage) ---
install_nyxt:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/atlas-engineer/nyxt/releases/download/4.0.0/Linux-Nyxt-x86_64.tar.gz -o /tmp/nyxt.tar.gz
        tar -xzf /tmp/nyxt.tar.gz -C /tmp
        mv /tmp/Nyxt-x86_64.AppImage ~/.local/bin/nyxt
        chmod +x ~/.local/bin/nyxt
        rm -f /tmp/nyxt.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/nyxt

# --- Open Sound Meter (FFT acoustic analysis, AppImage) ---
install_opensoundmeter:
  cmd.run:
    - name: curl -fsSL https://github.com/psmokotnin/osm/releases/download/v1.5.2/Open_Sound_Meter-v1.5.2-x86_64.AppImage -o ~/.local/bin/opensoundmeter && chmod +x ~/.local/bin/opensoundmeter
    - runas: neg
    - creates: /var/home/neg/.local/bin/opensoundmeter

# --- matugen (Material You color generation) ---
install_matugen:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/InioX/matugen/releases/download/v3.1.0/matugen-3.1.0-x86_64.tar.gz -o /tmp/matugen.tar.gz
        tar -xzf /tmp/matugen.tar.gz -C /tmp
        mv /tmp/matugen ~/.local/bin/
        rm -f /tmp/matugen.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/matugen

install_matugen_themes:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/InioX/matugen-themes.git /tmp/matugen-themes
        mkdir -p ~/.config/matugen/templates
        cp -r /tmp/matugen-themes/*/ ~/.config/matugen/templates/
        rm -rf /tmp/matugen-themes
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.config/matugen/templates

# --- DroidCam (phone as webcam via v4l2loopback) ---
install_v4l2loopback:
  cmd.run:
    - name: rpm-ostree install -y akmod-v4l2loopback
    - unless: rpm -q akmod-v4l2loopback &>/dev/null || rpm-ostree status | grep -q v4l2loopback

install_droidcam:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://files.dev47apps.net/linux/droidcam_2.1.3.zip -o /tmp/droidcam.zip
        unzip -o /tmp/droidcam.zip -d /tmp/droidcam
        mv /tmp/droidcam/droidcam ~/.local/bin/
        mv /tmp/droidcam/droidcam-cli ~/.local/bin/
        chmod +x ~/.local/bin/droidcam ~/.local/bin/droidcam-cli
        rm -rf /tmp/droidcam.zip /tmp/droidcam
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/droidcam

# --- blesh (Bash Line Editor) ---
install_blesh:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz -o /tmp/blesh.tar.xz
        tar -xJf /tmp/blesh.tar.xz -C ~/.local/share/ --strip-components=1
        rm -f /tmp/blesh.tar.xz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/ble.sh

# --- hishtory (synced shell history search) ---
install_hishtory:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/ddworken/hishtory/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/ddworken/hishtory/releases/download/${TAG}/hishtory-linux-amd64" -o ~/.local/bin/hishtory
        chmod +x ~/.local/bin/hishtory
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/hishtory

# --- iwmenu (interactive Wi-Fi menu for iwd/Wayland) ---
install_iwmenu:
  cmd.run:
    - name: cargo install --git https://github.com/e-tho/iwmenu
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/iwmenu

# --- ollama: systemd service + models ---
ollama_service_unit:
  file.managed:
    - name: /etc/systemd/system/ollama.service
    - contents: |
        [Unit]
        Description=Ollama LLM Server
        After=network-online.target

        [Service]
        ExecStart=/usr/bin/ollama serve
        User=neg
        Group=neg
        Restart=always
        RestartSec=3
        WorkingDirectory=/var/home/neg
        Environment="HOME=/var/home/neg"
        Environment="OLLAMA_HOST=127.0.0.1:11434"
        Environment="OLLAMA_MODELS=/var/mnt/one/ollama/models"

        [Install]
        WantedBy=default.target
    - user: root
    - group: root
    - mode: '0644'

ollama_models_dir:
  file.directory:
    - name: /var/mnt/one/ollama/models
    - user: neg
    - group: neg
    - makedirs: True
    - require:
      - mount: mount_one

ollama_selinux_context:
  cmd.run:
    - name: |
        semanage fcontext -a -t var_lib_t "/mnt/one/ollama(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t var_lib_t "/mnt/one/ollama(/.*)?"
        restorecon -Rv /var/mnt/one/ollama
    - unless: matchpathcon -V /var/mnt/one/ollama/models 2>&1 | grep -q verified
    - require:
      - file: ollama_models_dir

# ollama server (init_t) needs to read its key from ~/.ollama/ (user_home_t → var_lib_t)
# uses /var/home path per equivalency rule '/home /var/home'
ollama_selinux_homedir:
  cmd.run:
    - name: |
        semanage fcontext -a -t var_lib_t "/var/home/neg/\.ollama(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t var_lib_t "/var/home/neg/\.ollama(/.*)?"
        restorecon -Rv /var/home/neg/.ollama
    - unless: ls -Z /var/home/neg/.ollama/id_ed25519 | grep -q var_lib_t

# ollama runs as init_t (no custom SELinux type) and needs outbound HTTPS for model pulls
ollama_selinux_network:
  cmd.run:
    - name: |
        TMP=$(mktemp -d)
        cat > "$TMP/ollama-network.te" << 'POLICY'
        module ollama-network 1.0;
        require {
            type init_t;
            type http_port_t;
            class tcp_socket name_connect;
        }
        allow init_t http_port_t:tcp_socket name_connect;
        POLICY
        checkmodule -M -m -o "$TMP/ollama-network.mod" "$TMP/ollama-network.te"
        semodule_package -o "$TMP/ollama-network.pp" -m "$TMP/ollama-network.mod"
        semodule -i "$TMP/ollama-network.pp"
        rm -rf "$TMP"
    - unless: semodule -l | grep -q '^ollama-network'

ollama_enable:
  cmd.run:
    - name: systemctl daemon-reload && systemctl enable ollama
    - onchanges:
      - file: ollama_service_unit
    - onlyif: command -v ollama
    - require:
      - cmd: ollama_selinux_context

ollama_start:
  cmd.run:
    - name: |
        systemctl daemon-reload
        systemctl restart ollama
        for i in $(seq 1 30); do
          curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && exit 0
          sleep 1
        done
        echo "ollama failed to start within 30s" >&2
        exit 1
    - unless: curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1
    - require:
      - cmd: ollama_enable
      - cmd: ollama_selinux_homedir

{% for model in ['deepseek-r1:8b', 'llama3.2:3b', 'qwen2.5-coder:7b'] %}
pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}:
  cmd.run:
    - name: >-
        curl -sf --max-time 600
        -X POST http://127.0.0.1:11434/api/pull
        -d '{"name": "{{ model }}", "stream": false}'
    - unless: >-
        curl -sf http://127.0.0.1:11434/api/tags |
        grep -q '"{{ model }}"'
    - timeout: 600
    - require:
      - cmd: ollama_start
      - cmd: ollama_selinux_network
{% endfor %}

# --- openclaw (local AI assistant agent) ---
install_openclaw:
  cmd.run:
    - name: npm install -g openclaw
    - runas: neg
    - creates: /var/home/neg/.npm-global/bin/openclaw

# --- rofi-pass (password-store rofi frontend) ---
install_rofi_pass:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://raw.githubusercontent.com/carnager/rofi-pass/master/rofi-pass -o ~/.local/bin/rofi-pass
        chmod +x ~/.local/bin/rofi-pass
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/rofi-pass

# --- Theme packages not in Fedora repos ---
install_kora_icons:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/bikass/kora/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/bikass/kora/archive/refs/tags/${TAG}.tar.gz" -o /tmp/kora.tar.gz
        tar -xzf /tmp/kora.tar.gz -C /tmp
        mkdir -p ~/.local/share/icons
        cp -r /tmp/kora-*/kora ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light-panel ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-pgrey ~/.local/share/icons/
        gtk-update-icon-cache ~/.local/share/icons/kora 2>/dev/null || true
        rm -rf /tmp/kora.tar.gz /tmp/kora-*
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/icons/kora

install_flight_gtk_theme:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/neg-serg/Flight-Plasma-Themes.git /tmp/flight-gtk
        mkdir -p ~/.local/share/themes
        cp -r /tmp/flight-gtk/Flight-Dark-GTK ~/.local/share/themes/
        cp -r /tmp/flight-gtk/Flight-light-GTK ~/.local/share/themes/
        rm -rf /tmp/flight-gtk
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/themes/Flight-Dark-GTK

# --- MPV scripts (installed per-user, not in Fedora repos) ---
install_mpv_scripts:
  cmd.run:
    - name: |
        set -eo pipefail
        SCRIPTS_DIR=~/.config/mpv/scripts
        mkdir -p "$SCRIPTS_DIR"
        # uosc (modern UI)
        TAG=$(curl -fsSL https://api.github.com/repos/tomasklaen/uosc/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/tomasklaen/uosc/releases/download/${TAG}/uosc.zip" -o /tmp/uosc.zip
        unzip -qo /tmp/uosc.zip -d ~/.config/mpv/
        rm /tmp/uosc.zip
        # thumbfast
        curl -fsSL https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua -o "$SCRIPTS_DIR/thumbfast.lua"
        # sponsorblock
        curl -fsSL https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock.lua -o "$SCRIPTS_DIR/sponsorblock.lua"
        # quality-menu
        curl -fsSL https://raw.githubusercontent.com/christoph-heinrich/mpv-quality-menu/master/quality-menu.lua -o "$SCRIPTS_DIR/quality-menu.lua"
        # mpris
        TAG=$(curl -fsSL https://api.github.com/repos/hoyon/mpv-mpris/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/hoyon/mpv-mpris/releases/download/${TAG}/mpris.so" -o "$SCRIPTS_DIR/mpris.so"
        # cutter
        curl -fsSL https://raw.githubusercontent.com/rushmj/mpv-video-cutter/master/cutter.lua -o "$SCRIPTS_DIR/cutter.lua"
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.config/mpv/scripts/thumbfast.lua

# --- Systemd user services for media ---
# Remove legacy custom mpdris2.service (replaced by drop-in for RPM unit)
mpdris2_legacy_cleanup:
  file.absent:
    - name: /var/home/neg/.config/systemd/user/mpdris2.service

# Drop-in override for RPM-shipped mpDris2.service: adds MPD ordering
mpdris2_user_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/mpDris2.service.d/override.conf
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        After=mpd.service
        Wants=mpd.service

mpdris2_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
    - onchanges:
      - file: mpdris2_user_service

chezmoi_config:
  file.managed:
    - name: /var/home/neg/.config/chezmoi/chezmoi.toml
    - source: salt://dotfiles/dot_config/chezmoi/chezmoi.toml
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True

chezmoi_source_symlink:
  file.symlink:
    - name: /var/home/neg/.local/share/chezmoi
    - target: /var/home/neg/src/salt/dotfiles
    - user: neg
    - group: neg
    - force: True
    - makedirs: True
    - require:
      - user: user_neg
      - file: chezmoi_config

# --- Mail directories (needed by mbsync) ---
mail_directories:
  file.directory:
    - names:
      - /var/home/neg/.local/mail/gmail/INBOX
      - /var/home/neg/.local/mail/gmail/[Gmail]/Sent Mail
      - /var/home/neg/.local/mail/gmail/[Gmail]/Drafts
      - /var/home/neg/.local/mail/gmail/[Gmail]/All Mail
      - /var/home/neg/.local/mail/gmail/[Gmail]/Trash
      - /var/home/neg/.local/mail/gmail/[Gmail]/Spam
    - user: neg
    - group: neg
    - makedirs: True

# --- Systemd user services for mail ---
mbsync_gmail_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/mbsync-gmail.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Mailbox synchronization (Gmail)
        After=network-online.target
        Wants=network-online.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/mbsync gmail
        [Install]
        WantedBy=default.target

mbsync_gmail_timer:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/mbsync-gmail.timer
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Mailbox synchronization timer (Gmail)
        [Timer]
        OnBootSec=2min
        OnUnitActiveSec=10min
        [Install]
        WantedBy=timers.target

imapnotify_gmail_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/imapnotify-gmail.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=IMAP IDLE notifications (Gmail)
        After=network-online.target
        Wants=network-online.target
        [Service]
        ExecStart=/usr/bin/goimapnotify -conf %h/.config/imapnotify/gmail.json
        Restart=on-failure
        RestartSec=30
        [Install]
        WantedBy=default.target

# --- Systemd user services for calendar ---
vdirsyncer_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/vdirsyncer.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Synchronize calendars and contacts (vdirsyncer)
        After=network-online.target
        Wants=network-online.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/vdirsyncer sync

vdirsyncer_timer:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/vdirsyncer.timer
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Synchronize calendars and contacts timer
        [Timer]
        OnBootSec=2min
        OnUnitActiveSec=5min
        [Install]
        WantedBy=timers.target

# --- Surfingkeys HTTP server (browser extension helper) ---
surfingkeys_server_service:
  file.managed:
    - name: /var/home/neg/.config/systemd/user/surfingkeys-server.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Surfingkeys HTTP server (browser extension helper)
        After=graphical-session.target
        PartOf=graphical-session.target
        [Service]
        ExecStart=%h/.local/bin/surfingkeys-server
        Restart=on-failure
        RestartSec=5
        [Install]
        WantedBy=graphical-session.target

# --- Enable user services: single daemon-reload + batch enable ---
enable_user_services:
  cmd.run:
    - name: |
        systemctl --user daemon-reload
        systemctl --user enable imapnotify-gmail.service surfingkeys-server.service gpg-agent.socket gpg-agent-ssh.socket
        systemctl --user enable --now mbsync-gmail.timer vdirsyncer.timer
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - unless: |
        systemctl --user is-enabled imapnotify-gmail.service 2>/dev/null &&
        systemctl --user is-enabled mbsync-gmail.timer 2>/dev/null &&
        systemctl --user is-enabled vdirsyncer.timer 2>/dev/null &&
        systemctl --user is-enabled surfingkeys-server.service 2>/dev/null &&
        systemctl --user is-enabled gpg-agent-ssh.socket 2>/dev/null
    - require:
      - file: imapnotify_gmail_service
      - file: mbsync_gmail_timer
      - file: vdirsyncer_timer
      - file: surfingkeys_server_service

# --- SSH directory setup ---
ssh_dir:
  file.directory:
    - name: /var/home/neg/.ssh
    - user: neg
    - group: neg
    - mode: '0700'

# --- Wallust cache defaults (prevents hyprland source errors on first boot) ---
wallust_cache_dir:
  file.directory:
    - name: /var/home/neg/.cache/wallust
    - user: neg
    - group: neg
    - mode: '0755'

wallust_hyprland_defaults:
  file.managed:
    - name: /var/home/neg/.cache/wallust/hyprland.conf
    - user: neg
    - group: neg
    - mode: '0644'
    - replace: false
    - contents: |
        $col_border_active_base = rgba(00285981)
        $col_border_inactive   = rgba(00000000)
        $shadow_color          = rgba(005fafaa)
    - require:
      - file: wallust_cache_dir

# --- dconf: GTK/icon/font theme for Wayland apps ---
set_dconf_themes:
  cmd.run:
    - name: |
        dconf write /org/gnome/desktop/interface/gtk-theme "'Flight-Dark-GTK'"
        dconf write /org/gnome/desktop/interface/icon-theme "'kora'"
        dconf write /org/gnome/desktop/interface/font-name "'Iosevka 10'"
    - runas: neg
    - env:
      - DBUS_SESSION_BUS_ADDRESS: "unix:path=/run/user/1000/bus"
    - unless: |
        test "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Flight-Dark-GTK'" &&
        test "$(dconf read /org/gnome/desktop/interface/icon-theme)" = "'kora'" &&
        test "$(dconf read /org/gnome/desktop/interface/font-name)" = "'Iosevka 10'"
