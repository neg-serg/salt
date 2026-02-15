{% from 'host_config.jinja' import host %}
{% from 'packages.jinja' import flatpak_apps %}
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

sudo_nopasswd:
  file.managed:
    - name: /etc/sudoers.d/99-neg-nopasswd
    - contents: |
        neg ALL=(ALL) NOPASSWD: ALL
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

# Package lists: see packages.jinja (categories, flatpak, extensions)

include:
  - amnezia
  - bind_mounts
  - custom_pkgs
  - distrobox
  - dns
  - fira-code-nerd
  - floorp
  - greetd
  - hardware
  - hy3
  - installers
  - iosevka
  - kernel_modules
  - kernel_params
  - monitoring
  - mpd
  - network
  - ollama
  - services
  - sysctl
  - user_services

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

# Force shell update for users
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

# Flatpak applications (list in packages.jinja)
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

# --- SSH directory setup ---
ssh_dir:
  file.directory:
    - name: /home/neg/.ssh
    - user: neg
    - group: neg
    - mode: '0700'

# --- Wallust cache defaults (prevents hyprland source errors on first boot) ---
wallust_cache_dir:
  file.directory:
    - name: /home/neg/.cache/wallust
    - user: neg
    - group: neg
    - mode: '0755'

wallust_hyprland_defaults:
  file.managed:
    - name: /home/neg/.cache/wallust/hyprland.conf
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
