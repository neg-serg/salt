# Desktop environment: services, SSH, wallust defaults, dconf themes
{% from '_imports.jinja' import host, user, home, pkg_list %}
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_stopped %}
{% import_yaml 'data/desktop.yaml' as desktop %}

# --- Pacman hook: regenerate installed-package cache after every transaction ---
pacman_hooks_dir:
  file.directory:
    - name: /etc/pacman.d/hooks
    - mode: '0755'

pacman_salt_pkglist_hook:
  file.managed:
    - name: /etc/pacman.d/hooks/salt-pkglist.hook
    - source: salt://configs/pacman-salt-cache.hook
    - mode: '0644'
    - require:
      - file: pacman_hooks_dir

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
{% for svc in desktop.running_services %}
      - {{ svc }}
{% endfor %}
    - enable: True

# libvirtd is socket-activated: systemd starts it on demand and stops it when no VMs run.
# Keeping it in service.running would re-start it on every Salt apply.
libvirtd_enabled:
  service.enabled:
    - name: libvirtd

# Disable tuned: its throughput-performance profile conflicts with custom
# I/O tuning (sets read_ahead_kb=8192 on NVMe, may override sysctl values).
# All tuning is managed manually via sysctl.sls, kernel_params_limine.sls, hardware.sls.
{{ service_stopped('disable_tuned', 'tuned') }}

# --- Hyprland ecosystem packages ---
{{ pacman_install('hyprland_desktop',
    'hyprpaper hypridle hyprlock hyprpolkitagent xdg-desktop-portal-hyprland hyprpicker wlr-randr') }}
{{ pacman_install('screenshot_tools', 'grim slurp') }}
{{ pacman_install('rsync', 'rsync') }}

{{ paru_install('xdg-termfilechooser', 'xdg-desktop-portal-termfilechooser-boydaihungst-git') }}

{{ paru_install('wlr-which-key', 'wlr-which-key') }}

# --- SSH directory setup ---
{{ ensure_dir('ssh_dir', home ~ '/.ssh', mode='0700') }}

# --- Wallust cache defaults (prevents hyprland source errors on first boot) ---
{{ ensure_dir('wallust_cache_dir', home ~ '/.cache/wallust', mode='0755') }}

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
{% for key, val in desktop.dconf_settings.items() %}
        dconf write {{ key }} "'{{ val }}'"
{% endfor %}
    - runas: {{ user }}
    - env:
      - DBUS_SESSION_BUS_ADDRESS: "unix:path={{ host.runtime_dir }}/bus"
    - unless: |
{% for key, val in desktop.dconf_settings.items() %}
        test "$(dconf read {{ key }})" = "'{{ val }}'"{{ ' &&' if not loop.last else '' }}
{% endfor %}
