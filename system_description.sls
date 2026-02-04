# Salt state для Fedora Silverblue
# Учитывает иммутабельность файловой системы

system_timezone:
  timezone.system:
    - name: Europe/Moscow

system_hostname:
  cmd.run:
    - name: hostnamectl set-hostname fedora
    - unless: test "$(hostname)" = "fedora"

user_neg:
  user.present:
    - name: neg
    - shell: /bin/bash
    - uid: 1000
    - gid: 1000
    - groups:
      - neg

# Для Silverblue используем rpm-ostree через cmd.run, 
# так как нативного модуля в этой версии Salt нет.
{% set cli_packages = [
    'salt', 'ripgrep', 'tig', 'zsh', 'tree-sitter-cli', 'xsel', 'yt-dlp',
    'git', 'git-delta', 'fd-find', 'zoxide', 'ncdu', 'htop', 'fastfetch',
    'jq', 'aria2', 'p7zip', 'unzip', 'zip', 'xz', 'lsof', 'procps-ng',
    'psmisc', 'pv', 'parallel', 'perl-Image-ExifTool', 'chafa', 'convmv',
    'dos2unix', 'moreutils', 'duf', 'rmlint', 'ouch', 'nnn', 'stow',
    'dust', 'eza', 'pwgen', 'par', 'entr', 'inotify-tools', 'progress',
    'reptyr', 'goaccess', 'lnav', 'qrencode', 'asciinema', 'sox', 'zbar',
    'libnotify'
] %}

include:
  - amnezia

{% for pkg in cli_packages %}
ensure_pkg_{{ pkg }}:
  cmd.run:
    - name: rpm-ostree install {{ pkg }}
    - unless: rpm -q {{ pkg }}
{% endfor %}

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
