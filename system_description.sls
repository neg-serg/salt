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
{% for pkg in ['salt', 'ripgrep', 'tig', 'zsh', 'tree-sitter-cli', 'xsel', 'yt-dlp'] %}
ensure_pkg_{{ pkg }}:
  cmd.run:
    - name: rpm-ostree install {{ pkg }}
    - unless: rpm -q {{ pkg }}
{% endfor %}

amnezia_wg_repo:
  cmd.run:
    - name: dnf copr enable amneziavpn/amneziawg -y
    - unless: test -f /etc/yum.repos.d/_copr_amneziavpn-amneziawg.repo

ensure_amnezia_wg:
  cmd.run:
    - name: rpm-ostree cleanup -m && rpm-ostree install amneziawg-dkms amneziawg-tools
    - unless: rpm -q amneziawg-tools
    - require:
      - cmd: amnezia_wg_repo

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
