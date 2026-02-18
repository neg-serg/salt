# Desktop environment: services, SSH, wallust defaults, dconf themes
{% from 'host_config.jinja' import host %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% set user = host.user %}
{% set home = host.home %}

# --- Pacman hook: regenerate installed-package cache after every transaction ---
pacman_hooks_dir:
  file.directory:
    - name: /etc/pacman.d/hooks
    - mode: '0755'

pacman_salt_pkglist_hook:
  file.managed:
    - name: /etc/pacman.d/hooks/salt-pkglist.hook
    - mode: '0644'
    - require:
      - file: pacman_hooks_dir
    - contents: |
        [Trigger]
        Type = Package
        Operation = Install
        Operation = Upgrade
        Operation = Remove
        Target = *

        [Action]
        When = PostTransaction
        Exec = /bin/sh -c 'pacman -Qq > /var/cache/salt/pacman_installed.txt'
        Description = Refresh Salt package cache

pacman_salt_cache_dir:
  file.directory:
    - name: /var/cache/salt
    - mode: '0755'

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
      - openrgb
      - bluetooth
      - systemd-timesyncd
    - enable: True

# libvirtd is socket-activated: systemd starts it on demand and stops it when no VMs run.
# Keeping it in service.running would re-start it on every Salt apply.
libvirtd_enabled:
  service.enabled:
    - name: libvirtd

# Disable tuned: its throughput-performance profile conflicts with custom
# I/O tuning (sets read_ahead_kb=8192 on NVMe, may override sysctl values).
# All tuning is managed manually via sysctl.sls, kernel_params_limine.sls, hardware.sls.
disable_tuned:
  service.dead:
    - name: tuned
    - enable: False

# --- Hyprland ecosystem packages ---
{{ pacman_install('hyprland_desktop',
    'hyprpaper hypridle hyprlock hyprpolkitagent xdg-desktop-portal-hyprland hyprpicker wlr-randr') }}
{{ pacman_install('screenshot_tools', 'grim slurp') }}
{{ pacman_install('rsync', 'rsync') }}

remove_old_termfilechooser:
  cmd.run:
    - name: pacman -Rns --noconfirm xdg-desktop-portal-termfilechooser-git
    - onlyif: rg -qx 'xdg-desktop-portal-termfilechooser-git' /var/cache/salt/pacman_installed.txt

install_xdg_termfilechooser:
  cmd.run:
    - name: sudo -u {{ user }} paru -S --noconfirm --needed xdg-desktop-portal-termfilechooser-boydaihungst-git
    - unless: rg -qx 'xdg-desktop-portal-termfilechooser-boydaihungst-git' /var/cache/salt/pacman_installed.txt
    - require:
      - cmd: pacman_db_warmup
      - cmd: remove_old_termfilechooser

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
        set -eo pipefail
        dconf write /org/gnome/desktop/interface/gtk-theme "'Flight-Dark-GTK'"
        dconf write /org/gnome/desktop/interface/icon-theme "'kora'"
        dconf write /org/gnome/desktop/interface/font-name "'Iosevka 10'"
    - runas: {{ user }}
    - env:
      - DBUS_SESSION_BUS_ADDRESS: "unix:path={{ host.runtime_dir }}/bus"
    - unless: |
        test "$(dconf read /org/gnome/desktop/interface/gtk-theme)" = "'Flight-Dark-GTK'" &&
        test "$(dconf read /org/gnome/desktop/interface/icon-theme)" = "'kora'" &&
        test "$(dconf read /org/gnome/desktop/interface/font-name)" = "'Iosevka 10'"
