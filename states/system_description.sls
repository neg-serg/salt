{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}
{% set uid = host.uid %}
{% set runtime_dir = '/run/user/' ~ uid|string %}
# Salt state for CachyOS workstation
# Packages installed via pacman/paru outside Salt; Salt handles configuration

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
    - name: {{ user }}
    - shell: /usr/bin/zsh
    - uid: {{ uid }}
    - gid: {{ uid }}

plugdev_group:
  group.present:
    - name: plugdev
    - system: True

# user.present groups broken on Python 3.14 (crypt module removed)
neg_groups:
  cmd.run:
    - name: usermod -aG wheel,libvirt,plugdev {{ user }}
    - unless: id -nG {{ user }} | tr ' ' '\n' | grep -qx plugdev
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

sudo_nopasswd:
  file.managed:
    - name: /etc/sudoers.d/99-{{ user }}-nopasswd
    - contents: |
        {{ user }} ALL=(ALL) NOPASSWD: ALL
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

# Package lists: see packages.jinja (categories, flatpak, extensions)

include:
  - audio
  - amnezia
  - bind_mounts
  - custom_pkgs
  - dns
  - floorp
  - fonts
  - greetd
  - hardware
  - hy3
  - installers
  - installers_desktop
  - installers_themes
  - kernel_modules
  - kernel_params_limine
  - monitoring
  - mpd
  - network
  - ollama
  - services
  - steam
  - sysctl
  - user_services

zsh_config_dir:
  file.directory:
    - name: /etc/zsh
    - user: root
    - group: root
    - mode: '0755'

/etc/zsh/zshenv:
  file.managed:
    - contents: |
        # System-wide Zsh environment (zsh reads /etc/zsh/ on Arch)
        export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

/etc/zsh/zshrc:
  file.managed:
    - contents: |
        # System-wide zshrc (ZDOTDIR set in /etc/zsh/zshenv)
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

cleanup_old_etc_zshenv:
  file.absent:
    - name: /etc/zshenv

# Force shell update for users
force_zsh_neg:
  cmd.run:
    - name: usermod -s /usr/bin/zsh {{ user }}
    - unless: 'test "$(getent passwd {{ user }} | cut -d: -f7)" = "/usr/bin/zsh"'

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
      - dbus-broker
      - libvirtd
      - openrgb
      - bluetooth
      - systemd-timesyncd
    - enable: True

# Disable tuned: its throughput-performance profile conflicts with custom
# I/O tuning (sets read_ahead_kb=8192 on NVMe, may override sysctl values).
# All tuning is managed manually via sysctl.sls, kernel_params_limine.sls, hardware.sls.
disable_tuned:
  service.dead:
    - name: tuned
    - enable: False

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

# btrfs compression: set as filesystem property (complements fstab compress= option).
btrfs_compress_home:
  cmd.run:
    - name: btrfs property set /home compression zstd:-1
    - unless: btrfs property get /home compression 2>/dev/null | grep -q 'zstd:-1'

btrfs_compress_var:
  cmd.run:
    - name: btrfs property set /var compression zstd:-1
    - unless: btrfs property get /var compression 2>/dev/null | grep -q 'zstd:-1'

# --- SSH directory setup ---
ssh_dir:
  file.directory:
    - name: {{ home }}/.ssh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0700'

# --- Wallust cache defaults (prevents hyprland source errors on first boot) ---
wallust_cache_dir:
  file.directory:
    - name: {{ home }}/.cache/wallust
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

wallust_hyprland_defaults:
  file.managed:
    - name: {{ home }}/.cache/wallust/hyprland.conf
    - user: {{ user }}
    - group: {{ user }}
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
    - runas: {{ user }}
    - env:
      - DBUS_SESSION_BUS_ADDRESS: "unix:path={{ runtime_dir }}/bus"
    - unless: |
        test "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Flight-Dark-GTK'" &&
        test "$(dconf read /org/gnome/desktop/interface/icon-theme)" = "'kora'" &&
        test "$(dconf read /org/gnome/desktop/interface/font-name)" = "'Iosevka 10'"
