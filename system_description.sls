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
{% set cli_packages = [
    'salt', 'ripgrep', 'tig', 'zsh', 'tree-sitter-cli', 'xsel', 'yt-dlp',
    'git', 'git-delta', 'fd-find', 'zoxide', 'ncdu', 'htop', 'fastfetch',
    'jq', 'aria2', 'p7zip', 'unzip', 'zip', 'xz', 'lsof', 'procps-ng',
    'psmisc', 'pv', 'parallel', 'perl-Image-ExifTool', 'chafa', 'convmv',
    'dos2unix', 'moreutils', 'duf', 'rmlint', 'nnn', 'stow',
    'du-dust', 'pwgen', 'par', 'entr', 'inotify-tools', 'progress',
    'reptyr', 'goaccess', 'lnav', 'qrencode', 'asciinema', 'sox', 'zbar',
    'libnotify', 'kernel-devel', 'dkms', 'gcc', 'make', 'python3-devel',
    'chezmoi'
] %}

include:
  - amnezia

# Install all packages in a single transaction.
install_system_packages:
  cmd.run:
    - name: |
        {% raw %}
        pkgs=({% endraw %}{{ cli_packages | join(' ') }}{% raw %})
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
        pkgs=({% endraw %}{{ cli_packages | join(' ') }}{% raw %})
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-packages"[]?' | sort -u)
        for pkg in "${pkgs[@]}"; do
          if ! rpm -q "$pkg" &>/dev/null && ! echo "$layered" | grep -Fqx "$pkg"; then
            exit 1
          fi
        done
        {% endraw %}
    - require:
      - file: fix_containers_policy

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
