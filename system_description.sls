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
{% set categories = {
    'Archives': [
        {'name': 'p7zip',               'desc': 'Very high compression ratio file archiver'},
        {'name': 'unzip',               'desc': 'A utility for unpacking zip files'},
        {'name': 'xz',                  'desc': 'LZMA compression utilities'},
        {'name': 'zip',                 'desc': 'A file compression and packaging utility compatible with PKZIP'}
    ],
    'Development': [
        {'name': 'dkms',                'desc': 'Dynamic Kernel Module Support Framework'},
        {'name': 'gcc',                 'desc': 'Various compilers (C, C++, ...)'},
        {'name': 'just',                'desc': 'Just a command runner'},
        {'name': 'kernel-devel',        'desc': 'Development package for building kernel modules'},
        {'name': 'make',                'desc': 'A GNU tool which simplifies the build process for users'},
        {'name': 'python3-devel',       'desc': 'Libraries and header files needed for Python development'},
        {'name': 'tree-sitter-cli',     'desc': 'CLI tool for developing, testing, and using Tree-sitter parsers'}
    ],
    'File Management': [
        {'name': 'bat',                 'desc': 'A cat(1) clone with wings'},
        {'name': 'convmv',              'desc': 'Convert filename encodings'},
        {'name': 'dos2unix',            'desc': 'Text file format converters'},
        {'name': 'du-dust',             'desc': 'More intuitive version of du'},
        {'name': 'duf',                 'desc': 'Disk Usage/Free Utility - a better df alternative'},
        {'name': 'fd-find',             'desc': 'Fd is a simple, fast and user-friendly alternative to find'},
        {'name': 'ncdu',                'desc': 'Text-based disk usage viewer'},
        {'name': 'rmlint',              'desc': 'Find space waste and other broken things on your filesystem'},
        {'name': 'stow',                'desc': 'Manage the installation of software packages from source'}
    ],
    'Media': [
        {'name': 'cava',                'desc': 'Console audio visualizer'},
        {'name': 'chafa',               'desc': 'Image-to-text converter for terminal'},
        {'name': 'mpv',                 'desc': 'A free, open source, and cross-platform media player'},
        {'name': 'perl-Image-ExifTool', 'desc': 'Utility for reading and writing image meta info'},
        {'name': 'qrencode',            'desc': 'Generate QR 2D barcodes'},
        {'name': 'sox',                 'desc': 'A general purpose sound file conversion tool'},
        {'name': 'yt-dlp',              'desc': 'A command-line program to download videos from online video platforms'},
        {'name': 'zbar',                'desc': 'Bar code reader'}
    ],
    'Monitoring & System': [
        {'name': 'btop',                'desc': 'A monitor of resources (CPU, Memory, Network)'},
        {'name': 'fastfetch',           'desc': 'Fast neofetch-like system information tool'},
        {'name': 'goaccess',            'desc': 'Real-time web log analyzer and interactive viewer'},
        {'name': 'htop',                'desc': 'Interactive process viewer'},
        {'name': 'lnav',                'desc': 'Curses-based tool for viewing and analyzing log files'},
        {'name': 'lsof',                'desc': 'A utility which lists open files on a Linux/UNIX system'},
        {'name': 'procps-ng',           'desc': 'System and process monitoring utilities'},
        {'name': 'progress',            'desc': 'Coreutils Viewer'},
        {'name': 'psmisc',              'desc': 'Utilities for managing processes on your system'},
        {'name': 'pv',                  'desc': 'A tool for monitoring the progress of data through a pipeline'},
        {'name': 's-tui',               'desc': 'Stress terminal UI for CPU monitoring'},
        {'name': 'sysstat',             'desc': 'Performance monitoring tools'}
    ],
    'Network': [
        {'name': 'aria2',               'desc': 'High speed download utility with resuming and segmented downloading'},
        {'name': 'mtr',                 'desc': 'Network diagnostic tool'}
    ],
    'Shell & Tools': [
        {'name': 'asciinema',           'desc': 'Terminal session recorder, streamer and player'},
        {'name': 'entr',                'desc': 'Run arbitrary commands when files change'},
        {'name': 'fzf',                 'desc': 'A command-line fuzzy finder'},
        {'name': 'gh',                  'desc': 'GitHub CLI'},
        {'name': 'git-lfs',             'desc': 'Git Large File Storage'},
        {'name': 'inotify-tools',       'desc': 'Command line utilities for inotify'},
        {'name': 'kitty',               'desc': 'GPU-accelerated terminal emulator'},
        {'name': 'moreutils',           'desc': 'Additional unix utilities'},
        {'name': 'par',                 'desc': 'Paragraph reformatter, vaguely like fmt, but more elaborate'},
        {'name': 'parallel',            'desc': 'Shell tool for executing jobs in parallel'},
        {'name': 'pass',                'desc': 'The standard unix password manager'},
        {'name': 'pwgen',               'desc': 'Automatic password generation'},
        {'name': 'reptyr',              'desc': 'Attach a running process to a new terminal'},
        {'name': 'salt',                'desc': 'A parallel remote execution system'},
        {'name': 'tealdeer',            'desc': 'A fast tldr client in Rust'},
        {'name': 'tmux',                'desc': 'Terminal multiplexer'},
        {'name': 'zoxide',              'desc': 'Smarter cd command for your terminal'},
        {'name': 'zsh',                 'desc': 'Powerful interactive shell'}
    ],
    'Text & Search': [
        {'name': 'jq',                  'desc': 'Command-line JSON processor'},
        {'name': 'ripgrep',             'desc': 'Line-oriented search tool'}
    ],
    'Version Control': [
        {'name': 'chezmoi',             'desc': 'Manage your dotfiles across multiple diverse machines'},
        {'name': 'etckeeper',           'desc': 'Store /etc in a git repository'},
        {'name': 'git',                 'desc': 'Fast Version Control System'},
        {'name': 'git-delta',           'desc': 'Syntax-highlighting pager for git'},
        {'name': 'tig',                 'desc': 'Text-mode interface for the git revision control system'}
    ]
} %}

include:
  - amnezia
  - nix

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

generate_aliae_aliases:
  cmd.run:
    - name: ~/.local/bin/aliae init zsh --config ~/.config/aliae/aliae.yaml > ~/.config/zsh/06-aliae.zsh
    - runas: neg
    - require:
      - cmd: install_aliae

apply_dotfiles:
  cmd.run:
    - name: chezmoi apply --force --source /var/home/neg/src/salt/dotfiles
    - runas: neg
    - cwd: /var/home/neg
    - require:
      - cmd: install_system_packages

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
