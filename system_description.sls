# Salt state для Fedora Silverblue
# Учитывает иммутабельность файловой системы

# Исправляем политику контейнеров, чтобы podman мог скачивать образы
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

# Для Silverblue используем rpm-ostree.
# Батчим пакеты для ускорения и корректного разрешения зависимостей.
{% set cli_packages = [
    'salt', 'ripgrep', 'tig', 'zsh', 'tree-sitter-cli', 'xsel', 'yt-dlp',
    'git', 'git-delta', 'fd-find', 'zoxide', 'ncdu', 'htop', 'fastfetch',
    'aria2', 'p7zip', 'unzip', 'zip', 'xz', 'lsof', 'procps-ng',
    'psmisc', 'pv', 'parallel', 'perl-Image-ExifTool', 'chafa', 'convmv',
    'dos2unix', 'moreutils', 'duf', 'rmlint', 'nnn', 'stow',
    'du-dust', 'pwgen', 'par', 'entr', 'inotify-tools', 'progress',
    'reptyr', 'goaccess', 'lnav', 'qrencode', 'asciinema', 'sox', 'zbar',
    'libnotify', 'kernel-devel', 'dkms', 'gcc', 'make', 'python3-devel'
] %}

include:
  - amnezia

# Установка всех пакетов одной транзакцией.
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

# Установка RPM пакетов AmneziaWG (Tools и DKMS)
# Эти пакеты должны быть предварительно собраны скриптом build_amnezia.sh
install_amneziawg_rpms:
  cmd.run:
    - name: |
        {% raw %}
        rpms=(/var/home/neg/src/amnezia_build/amneziawg-tools-*.rpm /var/home/neg/src/amnezia_build/amneziawg-dkms-*.rpm)
        to_install=()
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-packages"[]?' | sort -u)
        
        # Check tools
        if ! rpm -q amneziawg-tools &>/dev/null && ! echo "$layered" | grep -Fqx "amneziawg-tools"; then
           to_install+=(/var/home/neg/src/amnezia_build/amneziawg-tools-*.rpm)
        fi
        # Check dkms
        if ! rpm -q amneziawg-dkms &>/dev/null && ! echo "$layered" | grep -Fqx "amneziawg-dkms"; then
           to_install+=(/var/home/neg/src/amnezia_build/amneziawg-dkms-*.rpm)
        fi

        if [ ${#to_install[@]} -gt 0 ]; then
          rpm-ostree install -y --allow-inactive "${to_install[@]}"
        fi
        {% endraw %}
    - onlyif: ls /var/home/neg/src/amnezia_build/amneziawg-tools-*.rpm && ls /var/home/neg/src/amnezia_build/amneziawg-dkms-*.rpm
    - require:
      - cmd: install_system_packages
      - cmd: build_amnezia_vpn

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