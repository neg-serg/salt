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
#   kitty, lsof, make, mtr, procps-ng, psmisc, qrencode, ripgrep, rust,
#   tree-sitter-cli, unzip, waybar, xz, yt-dlp, zip
# Hyprland-specific (shipped by image): hyprland, hyprland-qtutils, hyprlock,
#   hypridle, hyprpaper, xdg-desktop-portal-hyprland
{% set categories = {
    'Archives & Compression': [
        {'name': 'lbzip2',              'desc': 'Parallel bzip2 compression utility'},
        {'name': 'patool',              'desc': 'Portable archive file manager'},
        {'name': 'pbzip2',              'desc': 'Parallel bzip2 implementation'},
        {'name': 'pigz',                'desc': 'Parallel gzip implementation'},
        {'name': 'unar',                'desc': 'Universal archive unpacker'},
        {'name': 'unrar',               'desc': 'RAR archive extractor'}
    ],
    'Development': [
        {'name': 'cargo',               'desc': 'Rust package manager'},
        {'name': 'clang-libs',          'desc': 'Clang runtime libraries'},
        {'name': 'cmake',               'desc': 'Cross-platform build system'},
        {'name': 'dkms',                'desc': 'Dynamic Kernel Module Support Framework'},
        {'name': 'gcc',                 'desc': 'Various compilers (C, C++, ...)'},
        {'name': 'gdb',                 'desc': 'GNU Debugger'},
        {'name': 'hyperfine',           'desc': 'Command-line benchmarking tool'},
        {'name': 'just',                'desc': 'Just a command runner'},
        {'name': 'kernel-devel',        'desc': 'Development package for building kernel modules'},
        {'name': 'ncurses-devel',       'desc': 'Development files for ncurses'},
        {'name': 'pipewire-devel',      'desc': 'PipeWire development files'},
        {'name': 'pulseaudio-libs-devel', 'desc': 'PulseAudio development libraries'},
        {'name': 'python3-devel',       'desc': 'Libraries and header files needed for Python development'},
        {'name': 'ShellCheck',          'desc': 'Shell script analysis tool'},
        {'name': 'shfmt',               'desc': 'Shell script formatter'},
        {'name': 'strace',              'desc': 'System call tracer'}
    ],
    'File Management': [
        {'name': 'bat',                 'desc': 'A cat(1) clone with wings'},
        {'name': 'borgbackup',          'desc': 'Deduplicating archiver with compression and encryption'},
        {'name': 'convmv',              'desc': 'Convert filename encodings'},
        {'name': 'dos2unix',            'desc': 'Text file format converters'},
        {'name': 'du-dust',             'desc': 'More intuitive version of du'},
        {'name': 'enca',                'desc': 'Character set analyzer and converter'},
        {'name': 'fd-find',             'desc': 'Fd is a simple, fast and user-friendly alternative to find'},
        {'name': 'jdupes',              'desc': 'Duplicate file finder and remover'},
        {'name': 'ncdu',                'desc': 'Text-based disk usage viewer'},
        {'name': 'rmlint',              'desc': 'Find space waste and other broken things on your filesystem'},
        {'name': 'stow',                'desc': 'Manage the installation of software packages from source'}
    ],
    'Fonts': [
        {'name': 'material-icons-fonts', 'desc': 'Material Design icons fonts'}
    ],
    'Media': [
        {'name': 'advancecomp',         'desc': 'Recompression utilities for .png, .mng, .zip, .gz'},
        {'name': 'cava',                'desc': 'Console audio visualizer'},
        {'name': 'chafa',               'desc': 'Image-to-text converter for terminal'},
        {'name': 'darktable',           'desc': 'Utility to organize and develop raw images'},
        {'name': 'ffmpegthumbnailer',   'desc': 'Lightweight video thumbnailer'},
        {'name': 'jpegoptim',           'desc': 'Utility to optimize JPEG files'},
        {'name': 'mediainfo',           'desc': 'Media file information utility'},
        {'name': 'mpc',                 'desc': 'Command-line MPD client'},
        {'name': 'mpv',                 'desc': 'A free, open source, and cross-platform media player'},
        {'name': 'optipng',             'desc': 'PNG optimizer'},
        {'name': 'perl-Image-ExifTool', 'desc': 'Utility for reading and writing image meta info'},
        {'name': 'pngquant',            'desc': 'PNG quantization tool for lossy compression'},
        {'name': 'rawtherapee',         'desc': 'Raw image processing application'},
        {'name': 'sox',                 'desc': 'A general purpose sound file conversion tool'},
        {'name': 'swayimg',             'desc': 'Image viewer for Sway/Wayland'},
        {'name': 'zbar',                'desc': 'Bar code reader'}
    ],
    'Monitoring & System': [
        {'name': 'btop',                'desc': 'A monitor of resources (CPU, Memory, Network)'},
        {'name': 'fastfetch',           'desc': 'Fast neofetch-like system information tool'},
        {'name': 'goaccess',            'desc': 'Real-time web log analyzer and interactive viewer'},
        {'name': 'lnav',                'desc': 'Curses-based tool for viewing and analyzing log files'},
        {'name': 'progress',            'desc': 'Coreutils Viewer'},
        {'name': 'pv',                  'desc': 'A tool for monitoring the progress of data through a pipeline'},
        {'name': 's-tui',               'desc': 'Stress terminal UI for CPU monitoring'},
        {'name': 'sysstat',             'desc': 'Performance monitoring tools'}
    ],
    'Network': [
        {'name': 'aria2',               'desc': 'High speed download utility with resuming and segmented downloading'},
        {'name': 'prettyping',          'desc': 'Wrapper around ping to make output prettier'},
        {'name': 'speedtest-cli',       'desc': 'Command-line bandwidth test'},
        {'name': 'streamlink',          'desc': 'CLI for extracting streams from websites'}
    ],
    'Shell & Tools': [
        {'name': 'abduco',              'desc': 'Session management in a clean and simple way'},
        {'name': 'asciinema',           'desc': 'Terminal session recorder, streamer and player'},
        {'name': 'cpufetch',            'desc': 'Simple yet fancy CPU architecture fetching tool'},
        {'name': 'dcfldd',              'desc': 'Enhanced dd with hashing and status output'},
        {'name': 'entr',                'desc': 'Run arbitrary commands when files change'},
        {'name': 'expect',              'desc': 'Tool for automating interactive applications'},
        {'name': 'gh',                  'desc': 'GitHub CLI'},
        {'name': 'git-lfs',             'desc': 'Git Large File Storage'},
        {'name': 'glow',                'desc': 'Render markdown on the CLI'},
        {'name': 'jc',                  'desc': 'CLI tool to convert command output to JSON'},
        {'name': 'lowdown',             'desc': 'Markdown translator'},
        {'name': 'miller',              'desc': 'Like awk, sed, cut, join, and sort for name-indexed data'},
        {'name': 'moreutils',           'desc': 'Additional unix utilities'},
        {'name': 'par',                 'desc': 'Paragraph reformatter, vaguely like fmt, but more elaborate'},
        {'name': 'parallel',            'desc': 'Shell tool for executing jobs in parallel'},
        {'name': 'pass',                'desc': 'The standard unix password manager'},
        {'name': 'pastel',              'desc': 'CLI tool to generate, analyze, convert and manipulate colors'},
        {'name': 'pwgen',               'desc': 'Automatic password generation'},
        {'name': 'reptyr',              'desc': 'Attach a running process to a new terminal'},
        {'name': 'rlwrap',              'desc': 'Readline wrapper for interactive commands'},
        {'name': 'sad',                 'desc': 'CLI search and replace'},
        {'name': 'salt',                'desc': 'A parallel remote execution system'},
        {'name': 'tealdeer',            'desc': 'A fast tldr client in Rust'},
        {'name': 'tmux',                'desc': 'Terminal multiplexer'},
        {'name': 'ugrep',              'desc': 'Ultra fast grep with interactive query UI'},
        {'name': 'urlscan',             'desc': 'Extract and browse URLs from email messages'},
        {'name': 'yq',                  'desc': 'YAML/XML/TOML processor'},
        {'name': 'zoxide',              'desc': 'Smarter cd command for your terminal'},
        {'name': 'zsh',                 'desc': 'Powerful interactive shell'}
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
