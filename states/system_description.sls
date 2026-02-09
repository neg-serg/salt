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

system_locale:
  cmd.run:
    - name: localectl set-locale LANG=en_US.UTF-8
    - unless: localectl status | grep -q 'LANG=en_US.UTF-8'

system_keymap:
  cmd.run:
    - name: localectl set-x11-keymap ru,us
    - unless: localectl status | grep -q 'X11 Layout.*ru'

system_hostname:
  cmd.run:
    - name: hostnamectl set-hostname fedora
    - unless: test "$(hostname)" = "fedora"

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
    - groups:
      - neg
      - wheel

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
{% set categories = {
    'Archives & Compression': [
        {'name': 'lbzip2',              'desc': 'Parallel bzip2 compression utility'},
        {'name': 'patool',              'desc': 'Portable archive file manager'},
        {'name': 'pbzip2',              'desc': 'Parallel bzip2 implementation'},
        {'name': 'pigz',                'desc': 'Parallel gzip implementation'},
        {'name': 'unar',                'desc': 'Universal archive unpacker'}
    ],
    'Development': [
        {'name': 'cargo',               'desc': 'Rust package manager'},
        {'name': 'clang-libs',          'desc': 'Clang runtime libraries'},
        {'name': 'cmake',               'desc': 'Cross-platform build system'},
        {'name': 'difftastic',          'desc': 'Structural diff tool'},
        {'name': 'direnv',              'desc': 'Per-directory shell configuration tool'},
        {'name': 'dkms',                'desc': 'Dynamic Kernel Module Support Framework'},
        {'name': 'elfutils',            'desc': 'ELF binary analysis tools'},
        {'name': 'gcc',                 'desc': 'Various compilers (C, C++, ...)'},
        {'name': 'gdb',                 'desc': 'GNU Debugger'},
        {'name': 'graphviz',            'desc': 'Graph visualization tools'},
        {'name': 'helix',               'desc': 'Post-modern modal text editor'},
        {'name': 'hexyl',               'desc': 'Hex viewer with colored output'},
        {'name': 'hyperfine',           'desc': 'Command-line benchmarking tool'},
        {'name': 'just',                'desc': 'Just a command runner'},
        {'name': 'kernel-devel',        'desc': 'Development package for building kernel modules'},
        {'name': 'lldb',                'desc': 'LLVM debugger'},
        {'name': 'ncurses-devel',       'desc': 'Development files for ncurses'},
        {'name': 'perf',                'desc': 'Performance analysis tools for Linux'},
        {'name': 'pgcli',               'desc': 'PostgreSQL CLI with autocomplete'},
        {'name': 'pipewire-devel',      'desc': 'PipeWire development files'},
        {'name': 'pulseaudio-libs-devel', 'desc': 'PulseAudio development libraries'},
        {'name': 'python3-devel',       'desc': 'Libraries and header files needed for Python development'},
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
        {'name': 'ranger',              'desc': 'Terminal file manager with vi keybindings'},
        {'name': 'rclone',              'desc': 'Cloud storage sync tool'},
        {'name': 'rmlint',              'desc': 'Find space waste and other broken things on your filesystem'},
        {'name': 'stow',                'desc': 'Manage the installation of software packages from source'},
        {'name': 'testdisk',            'desc': 'Data recovery and partition repair tool'}
    ],
    'Fonts': [
        {'name': 'material-icons-fonts', 'desc': 'Material Design icons fonts'}
    ],
    'Media': [
        {'name': 'advancecomp',         'desc': 'Recompression utilities for .png, .mng, .zip, .gz'},
        {'name': 'beets',               'desc': 'Music library manager and tagger'},
        {'name': 'cava',                'desc': 'Console audio visualizer'},
        {'name': 'cdparanoia',          'desc': 'Secure CD ripper'},
        {'name': 'chafa',               'desc': 'Image-to-text converter for terminal'},
        {'name': 'darktable',           'desc': 'Utility to organize and develop raw images'},
        {'name': 'ffmpegthumbnailer',   'desc': 'Lightweight video thumbnailer'},
        {'name': 'helvum',              'desc': 'GTK patchbay for PipeWire'},
        {'name': 'id3v2',               'desc': 'Command-line ID3v2 tag editor'},
        {'name': 'jpegoptim',           'desc': 'Utility to optimize JPEG files'},
        {'name': 'mediainfo',           'desc': 'Media file information utility'},
        {'name': 'mpd',                 'desc': 'Music Player Daemon'},
        {'name': 'mpc',                 'desc': 'Command-line MPD client'},
        {'name': 'mpdas',               'desc': 'Last.fm scrobbler for MPD'},
        {'name': 'mpdris2',             'desc': 'MPRIS2 bridge for MPD'},
        {'name': 'mpv',                 'desc': 'A free, open source, and cross-platform media player'},
        {'name': 'optipng',             'desc': 'PNG optimizer'},
        {'name': 'perl-Image-ExifTool', 'desc': 'Utility for reading and writing image meta info'},
        {'name': 'picard',              'desc': 'MusicBrainz GUI music tagger'},
        {'name': 'pngquant',            'desc': 'PNG quantization tool for lossy compression'},
        {'name': 'qpwgraph',            'desc': 'Qt PipeWire patchbay'},
        {'name': 'rawtherapee',         'desc': 'Raw image processing application'},
        {'name': 'raysession',          'desc': 'Session manager for audio production'},
        {'name': 'rnnoise',             'desc': 'Real-time noise suppression library'},
        {'name': 'sonic-visualiser',    'desc': 'Audio analysis and visualization'},
        {'name': 'sox',                 'desc': 'A general purpose sound file conversion tool'},
        {'name': 'swayimg',             'desc': 'Image viewer for Sway/Wayland'},
        {'name': 'tesseract',           'desc': 'OCR engine'},
        {'name': 'zbar',                'desc': 'Bar code reader'}
    ],
    'Monitoring & System': [
        {'name': 'acpi',                'desc': 'ACPI battery and thermal info'},
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
        {'name': 'nethogs',             'desc': 'Per-process network bandwidth monitor'},
        {'name': 'nvtop',               'desc': 'GPU process monitor'},
        {'name': 'parted',              'desc': 'GNU Partition Editor'},
        {'name': 'powertop',            'desc': 'Power consumption analyzer'},
        {'name': 'progress',            'desc': 'Coreutils Viewer'},
        {'name': 'pv',                  'desc': 'A tool for monitoring the progress of data through a pipeline'},
        {'name': 's-tui',               'desc': 'Stress terminal UI for CPU monitoring'},
        {'name': 'schedtool',           'desc': 'CPU scheduling policy control'},
        {'name': 'smartmontools',       'desc': 'S.M.A.R.T. disk monitoring tools'},
        {'name': 'sysstat',             'desc': 'Performance monitoring tools'},
        {'name': 'vmtouch',             'desc': 'Virtual memory touch / file paging tool'},
        {'name': 'vnstat',              'desc': 'Network traffic monitor'}
    ],
    'Network': [
        {'name': 'aria2',               'desc': 'High speed download utility with resuming and segmented downloading'},
        {'name': 'axel',                'desc': 'Multi-threaded download accelerator'},
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
        {'name': 'speedtest-cli',       'desc': 'Command-line bandwidth test'},
        {'name': 'sshpass',             'desc': 'Non-interactive SSH password auth'},
        {'name': 'streamlink',          'desc': 'CLI for extracting streams from websites'},
        {'name': 'telegram-desktop',    'desc': 'Telegram Desktop messaging app'},
        {'name': 'traceroute',          'desc': 'Trace packet route to host'},
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
        {'name': 'lowdown',             'desc': 'Markdown translator'},
        {'name': 'miller',              'desc': 'Like awk, sed, cut, join, and sort for name-indexed data'},
        {'name': 'minicom',             'desc': 'Serial console and communication program'},
        {'name': 'moreutils',           'desc': 'Additional unix utilities'},
        {'name': 'mtools',              'desc': 'MS-DOS disk utilities'},
        {'name': 'neo',                 'desc': 'Matrix digital rain effect'},
        {'name': 'neomutt',             'desc': 'Terminal email client'},
        {'name': 'netmask',             'desc': 'IP address and netmask manipulation'},
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
        {'name': 'yq',                  'desc': 'YAML/XML/TOML processor'},
        {'name': 'zathura',             'desc': 'Minimal document viewer'},
        {'name': 'zathura-pdf-poppler', 'desc': 'PDF plugin for zathura'},
        {'name': 'zoxide',              'desc': 'Smarter cd command for your terminal'},
        {'name': 'zsh',                 'desc': 'Powerful interactive shell'}
    ],
    'Wayland': [
        {'name': 'cliphist',            'desc': 'Clipboard history for Wayland'},
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
        {'name': 'abuse',               'desc': 'Action platformer game'},
        {'name': 'crawl-tiles',         'desc': 'Dungeon Crawl Stone Soup with tiles'},
        {'name': 'dosbox-staging',      'desc': 'Modernized DOSBox fork'},
        {'name': 'gamescope',           'desc': 'SteamOS session compositing window manager'},
        {'name': 'gnuchess',            'desc': 'GNU Chess engine'},
        {'name': 'mangohud',            'desc': 'Vulkan/OpenGL overlay for FPS and system monitoring'},
        {'name': 'nethack',             'desc': 'Classic roguelike adventure game'},
        {'name': 'pcem',                'desc': 'IBM PC emulator'},
        {'name': 'protontricks',        'desc': 'Proton/Wine tricks helper'},
        {'name': 'retroarch',           'desc': 'Multi-platform emulator frontend'},
        {'name': 'supertuxkart',        'desc': '3D racing game'},
        {'name': 'wesnoth',             'desc': 'Turn-based strategy game'},
        {'name': 'xaos',                'desc': 'Interactive fractal zoomer'},
        {'name': 'xonotic',             'desc': 'Fast-paced FPS game'}
    ],
    'Security': [
        {'name': 'hashcat',             'desc': 'Advanced password recovery tool'},
        {'name': 'tcpdump',             'desc': 'Network packet analyzer'},
        {'name': 'wireshark-cli',       'desc': 'Network protocol analyzer CLI (tshark)'}
    ],
    'Virtualization': [
        {'name': 'bottles',             'desc': 'Wine/Proton application manager'},
        {'name': 'qemu-kvm',            'desc': 'QEMU/KVM virtual machine emulator'},
        {'name': 'virt-manager',        'desc': 'Virtual machine manager GUI'}
    ],
    'Desktop': [
        {'name': 'corectrl',            'desc': 'AMD GPU power and fan control'},
        {'name': 'ddccontrol',          'desc': 'DDC monitor control'},
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

include:
  - amnezia
  - build_rpms
  - fira-code-nerd
  - hy3
  - install_rpms
  - kernel_modules
  - kernel_params
  - mpd
  - sysctl

# Install all packages in a single transaction.
install_system_packages:
  cmd.run:
    - name: |
        {% raw %}
        pkgs=({% endraw %}{% for cat, pkgs in categories | dictsort %}{% for pkg in pkgs %}{{ pkg.name }} {% endfor %}{% endfor %}{% raw %})
        to_install=()
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-packages"[]?' | sort -u)
        for pkg in "${pkgs[@]}"; do
          if ! rpm -q "$pkg" &>/dev/null && ! echo "$layered" | grep -Fqx "$pkg"; then
            to_install+=("$pkg")
          fi
        done
        if [ ${#to_install[@]} -gt 0 ]; then
          rpm-ostree install -y --allow-inactive "${to_install[@]}"
        fi
        {% endraw %}
    - unless: |
        {% raw %}
        pkgs=({% endraw %}{% for cat, pkgs in categories | dictsort %}{% for pkg in pkgs %}{{ pkg.name }} {% endfor %}{% endfor %}{% raw %})
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-packages"[]?' | sort -u)
        for pkg in "${pkgs[@]}"; do
          if ! rpm -q "$pkg" &>/dev/null && ! echo "$layered" | grep -Fqx "$pkg"; then
            exit 1
          fi
        done
        {% endraw %}
    - require:
      - file: fix_containers_policy

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
    - require:
      - cmd: install_system_packages

running_services:
  service.running:
    - names:
      - NetworkManager
      - firewalld
      - chronyd
      - dbus-broker
      - bluetooth
    - enable: True

/mnt/zero:
  file.directory:
    - makedirs: True

mount_zero:
  mount.mounted:
    - name: /mnt/zero
    - device: /dev/mapper/argon-zero
    - fstype: xfs
    - mkmnt: True
    - opts: defaults
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
    - opts: defaults
    - persist: True

# Flatpak applications (32-bit deps conflict with rpm-ostree base image)
install_flatpak_steam:
  cmd.run:
    - name: flatpak install -y flathub com.valvesoftware.Steam
    - runas: neg
    - unless: flatpak info com.valvesoftware.Steam &>/dev/null

flatpak_steam_filesystem:
  cmd.run:
    - name: >-
        flatpak override --user
        --filesystem=/mnt/zero
        --filesystem=/mnt/one
        com.valvesoftware.Steam
    - runas: neg
    - require:
      - cmd: install_flatpak_steam
    - unless: flatpak override --user --show com.valvesoftware.Steam | grep -q '/mnt/zero'

install_flatpak_pcsx2:
  cmd.run:
    - name: flatpak install -y flathub net.pcsx2.PCSX2
    - runas: neg
    - unless: flatpak info net.pcsx2.PCSX2 &>/dev/null

install_flatpak_floorp:
  cmd.run:
    - name: flatpak install -y flathub one.ablaze.floorp
    - runas: neg
    - unless: flatpak info one.ablaze.floorp &>/dev/null

# --- Floorp browser: user.js + userChrome.css + userContent.css ---
floorp_user_js:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/user.js
    - source: salt://dotfiles/dot_config/tridactyl/user.js
    - user: neg
    - group: neg
    - makedirs: True

floorp_userchrome:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/chrome/userChrome.css
    - source: salt://dotfiles/dot_config/tridactyl/mozilla/userChrome.css
    - user: neg
    - group: neg
    - makedirs: True

floorp_usercontent:
  file.managed:
    - name: /var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default/chrome/userContent.css
    - source: salt://dotfiles/dot_config/tridactyl/mozilla/userContent.css
    - user: neg
    - group: neg
    - makedirs: True

# --- Floorp extensions (download .xpi into profile) ---
{% set floorp_profile = '/var/home/neg/.var/app/one.ablaze.floorp/.floorp/ltjcyqj7.default-default' %}
{% set floorp_extensions = [
    {'id': 'tridactyl.vim@cmcaine.co.uk',                    'slug': 'tridactyl-vim'},
    {'id': 'uBlock0@raymondhill.net',                         'slug': 'ublock-origin'},
    {'id': 'addon@darkreader.org',                            'slug': 'darkreader'},
    {'id': 'sponsorBlocker@ajay.app',                         'slug': 'sponsorblock'},
    {'id': '{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}',         'slug': 'styl-us'},
    {'id': '{aecec67f-0d10-4fa7-b7c7-609a2db280cf}',         'slug': 'violentmonkey'},
    {'id': '{531906d3-e22f-4a6c-a102-8057b88a1a63}',         'slug': 'single-file'},
    {'id': 'addon@fastforward.team',                          'slug': 'fastforwardteam'},
    {'id': 'hide-scrollbars@qashto',                          'slug': 'hide-scrollbars'},
    {'id': 'kellyc-show-youtube-dislikes@nradiowave',         'slug': 'kellyc-show-youtube-dislikes'},
    {'id': '{4a311e5c-1ccc-49b7-9c23-3e2b47b6c6d5}',         'slug': 'скачать-музыку-с-вк-vkd'},
] %}

{% for ext in floorp_extensions %}
floorp_ext_{{ ext.slug | replace('-', '_') }}:
  cmd.run:
    - name: curl -sL -o '{{ floorp_profile }}/extensions/{{ ext.id }}.xpi' 'https://addons.mozilla.org/firefox/downloads/latest/{{ ext.slug }}/latest.xpi'
    - creates: {{ floorp_profile }}/extensions/{{ ext.id }}.xpi
    - runas: neg
    - require:
      - cmd: install_flatpak_floorp
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
    - name: curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    - runas: neg
    - creates: /var/home/neg/.local/bin/oh-my-posh

install_aliae:
  cmd.run:
    - name: curl -L https://github.com/p-nerd/aliae/releases/latest/download/aliae-linux-amd64 -o ~/.local/bin/aliae && chmod +x ~/.local/bin/aliae
    - runas: neg
    - creates: /var/home/neg/.local/bin/aliae

install_grimblast:
  cmd.run:
    - name: curl -sL https://raw.githubusercontent.com/hyprwm/contrib/main/grimblast/grimblast -o ~/.local/bin/grimblast && chmod +x ~/.local/bin/grimblast
    - runas: neg
    - creates: /var/home/neg/.local/bin/grimblast

# --- COPR: noise-suppression-for-voice (RNNoise LADSPA plugin) ---
copr_noise_suppression:
  cmd.run:
    - name: dnf copr enable -y lkiesow/noise-suppression-for-voice
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lkiesow:noise-suppression-for-voice.repo

install_noise_suppression:
  cmd.run:
    - name: rpm-ostree install -y noise-suppression-for-voice
    - require:
      - cmd: copr_noise_suppression
    - unless: rpm-ostree status | grep -q noise-suppression-for-voice

install_yazi:
  cmd.run:
    - name: |
        curl -L https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip -o /tmp/yazi.zip
        unzip -o /tmp/yazi.zip -d /tmp/yazi_extracted
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/ya ~/.local/bin/
        rm -rf /tmp/yazi.zip /tmp/yazi_extracted
    - runas: neg
    - creates: /var/home/neg/.local/bin/yazi

install_broot:
  cmd.run:
    - name: curl -L https://dystroy.org/broot/download/x86_64-linux/broot -o ~/.local/bin/broot && chmod +x ~/.local/bin/broot
    - runas: neg
    - creates: /var/home/neg/.local/bin/broot

install_nushell:
  cmd.run:
    - name: |
        curl -L https://github.com/nushell/nushell/releases/latest/download/nu-$(curl -s https://api.github.com/repos/nushell/nushell/releases/latest | jq -r .tag_name)-x86_64-unknown-linux-musl.tar.gz -o /tmp/nu.tar.gz
        tar -xzf /tmp/nu.tar.gz -C /tmp
        mv /tmp/nu-*-x86_64-unknown-linux-musl/nu* ~/.local/bin/
        rm -rf /tmp/nu.tar.gz /tmp/nu-*-x86_64-unknown-linux-musl
    - runas: neg
    - creates: /var/home/neg/.local/bin/nu

install_eza:
  cmd.run:
    - name: |
        curl -L https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz -o /tmp/eza.tar.gz
        tar -xzf /tmp/eza.tar.gz -C /tmp
        mv /tmp/eza ~/.local/bin/
        rm /tmp/eza.tar.gz
    - runas: neg
    - creates: /var/home/neg/.local/bin/eza

install_television:
  cmd.run:
    - name: |
        TAG=$(curl -s https://api.github.com/repos/alexpasmantier/television/releases/latest | jq -r .tag_name)
        curl -L "https://github.com/alexpasmantier/television/releases/download/${TAG}/tv-${TAG}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/tv.tar.gz
        tar -xzf /tmp/tv.tar.gz -C /tmp
        mv /tmp/tv-${TAG}-x86_64-unknown-linux-musl/tv ~/.local/bin/
        rm -rf /tmp/tv.tar.gz /tmp/tv-${TAG}-x86_64-unknown-linux-musl
    - runas: neg
    - creates: /var/home/neg/.local/bin/tv

# --- Theme packages not in Fedora repos ---
install_kora_icons:
  cmd.run:
    - name: |
        TAG=$(curl -s https://api.github.com/repos/bikass/kora/releases/latest | jq -r .tag_name)
        curl -L "https://github.com/bikass/kora/archive/refs/tags/${TAG}.tar.gz" -o /tmp/kora.tar.gz
        tar -xzf /tmp/kora.tar.gz -C /tmp
        mkdir -p ~/.local/share/icons
        cp -r /tmp/kora-*/kora ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light-panel ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-pgrey ~/.local/share/icons/
        gtk-update-icon-cache ~/.local/share/icons/kora 2>/dev/null || true
        rm -rf /tmp/kora.tar.gz /tmp/kora-*
    - runas: neg
    - creates: /var/home/neg/.local/share/icons/kora

install_flight_gtk_theme:
  cmd.run:
    - name: |
        git clone --depth=1 https://github.com/neg-serg/Flight-Plasma-Themes.git /tmp/flight-gtk
        mkdir -p ~/.local/share/themes
        cp -r /tmp/flight-gtk/Flight-Dark-GTK ~/.local/share/themes/
        cp -r /tmp/flight-gtk/Flight-light-GTK ~/.local/share/themes/
        rm -rf /tmp/flight-gtk
    - runas: neg
    - creates: /var/home/neg/.local/share/themes/Flight-Dark-GTK

# --- MPV scripts (installed per-user, not in Fedora repos) ---
install_mpv_scripts:
  cmd.run:
    - name: |
        SCRIPTS_DIR=~/.config/mpv/scripts
        mkdir -p "$SCRIPTS_DIR"
        # uosc (modern UI)
        TAG=$(curl -s https://api.github.com/repos/tomasklaen/uosc/releases/latest | jq -r .tag_name)
        curl -sL "https://github.com/tomasklaen/uosc/releases/download/${TAG}/uosc.zip" -o /tmp/uosc.zip
        unzip -qo /tmp/uosc.zip -d ~/.config/mpv/
        rm /tmp/uosc.zip
        # thumbfast
        curl -sL https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua -o "$SCRIPTS_DIR/thumbfast.lua"
        # sponsorblock
        curl -sL https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock.lua -o "$SCRIPTS_DIR/sponsorblock.lua"
        # quality-menu
        curl -sL https://raw.githubusercontent.com/christoph-heinrich/mpv-quality-menu/master/quality-menu.lua -o "$SCRIPTS_DIR/quality-menu.lua"
        # mpris
        TAG=$(curl -s https://api.github.com/repos/hoyon/mpv-mpris/releases/latest | jq -r .tag_name)
        curl -sL "https://github.com/hoyon/mpv-mpris/releases/download/${TAG}/mpris.so" -o "$SCRIPTS_DIR/mpris.so"
        # cutter
        curl -sL https://raw.githubusercontent.com/rushmj/mpv-video-cutter/master/cutter.lua -o "$SCRIPTS_DIR/cutter.lua"
    - runas: neg
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

# --- GPG agent with SSH support ---
gpg_agent_socket:
  cmd.run:
    - name: systemctl --user enable gpg-agent.socket gpg-agent-ssh.socket
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
    - unless: systemctl --user is-enabled gpg-agent-ssh.socket

# --- SSH directory setup ---
ssh_dir:
  file.directory:
    - name: /var/home/neg/.ssh
    - user: neg
    - group: neg
    - mode: '0700'

# --- GPG keyring migration (old ~/.gnupg → XDG ~/.local/share/gnupg) ---
gnupg_xdg_dir:
  file.directory:
    - name: /var/home/neg/.local/share/gnupg
    - user: neg
    - group: neg
    - mode: '0700'

gnupg_xdg_private_keys_dir:
  file.directory:
    - name: /var/home/neg/.local/share/gnupg/private-keys-v1.d
    - user: neg
    - group: neg
    - mode: '0700'
    - require:
      - file: gnupg_xdg_dir

gnupg_migrate_pubkey:
  cmd.run:
    - name: GNUPGHOME=/var/home/neg/.gnupg gpg --export 9629B754BC0D843F7304BCF0F2CF6AB037FFADB1 | gpg --homedir /var/home/neg/.local/share/gnupg --import
    - runas: neg
    - onlyif: test -f /var/home/neg/.gnupg/pubring.kbx
    - unless: gpg --homedir /var/home/neg/.local/share/gnupg --list-keys 9629B754BC0D843F7304BCF0F2CF6AB037FFADB1 2>/dev/null
    - require:
      - file: gnupg_xdg_dir

gnupg_migrate_trust:
  cmd.run:
    - name: echo "9629B754BC0D843F7304BCF0F2CF6AB037FFADB1:6:" | gpg --homedir /var/home/neg/.local/share/gnupg --import-ownertrust
    - runas: neg
    - unless: gpg --homedir /var/home/neg/.local/share/gnupg --export-ownertrust 2>/dev/null | grep -q 9629B754BC0D843F7304BCF0F2CF6AB037FFADB1
    - require:
      - cmd: gnupg_migrate_pubkey

gnupg_migrate_key_stubs:
  cmd.run:
    - name: cp -n /var/home/neg/.gnupg/private-keys-v1.d/*.key /var/home/neg/.local/share/gnupg/private-keys-v1.d/
    - runas: neg
    - onlyif: test -d /var/home/neg/.gnupg/private-keys-v1.d
    - unless: test "$(ls /var/home/neg/.local/share/gnupg/private-keys-v1.d/*.key 2>/dev/null | wc -l)" -gt 0
    - require:
      - file: gnupg_xdg_private_keys_dir

# --- Gopass store migration (old ~/.password-store → XDG ~/.local/share/pass) ---
gopass_store_dir:
  file.directory:
    - name: /var/home/neg/.local/share/pass
    - user: neg
    - group: neg
    - mode: '0700'

gopass_store_migrate:
  cmd.run:
    - name: cp -a /var/home/neg/.password-store/. /var/home/neg/.local/share/pass/
    - runas: neg
    - onlyif: test -f /var/home/neg/.password-store/.gpg-id
    - unless: test -f /var/home/neg/.local/share/pass/.gpg-id
    - require:
      - file: gopass_store_dir

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

# --- dconf: GTK/icon/font/cursor theme for Wayland apps ---
set_dconf_gtk_theme:
  cmd.run:
    - name: dconf write /org/gnome/desktop/interface/gtk-theme "'Flight-Dark-GTK'"
    - runas: neg
    - unless: test "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Flight-Dark-GTK'"

set_dconf_icon_theme:
  cmd.run:
    - name: dconf write /org/gnome/desktop/interface/icon-theme "'kora'"
    - runas: neg
    - unless: test "$(dconf read /org/gnome/desktop/interface/icon-theme)" = "'kora'"

set_dconf_font_name:
  cmd.run:
    - name: dconf write /org/gnome/desktop/interface/font-name "'Iosevka 10'"
    - runas: neg
    - unless: test "$(dconf read /org/gnome/desktop/interface/font-name)" = "'Iosevka 10'"
