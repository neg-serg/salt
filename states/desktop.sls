# Desktop environment: services, SSH, wallust defaults, dconf themes
{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_stopped %}
{% import_yaml 'data/desktop.yaml' as desktop %}

# --- Pacman hook: regenerate installed-package cache after every transaction ---
{{ ensure_dir('pacman_hooks_dir', '/etc/pacman.d/hooks', mode='0755', user='root') }}

pacman_salt_pkglist_hook:
  file.managed:
    - name: /etc/pacman.d/hooks/salt-pkglist.hook
    - source: salt://configs/pacman-salt-cache.hook
    - mode: '0644'
    - require:
      - file: pacman_hooks_dir

{{ ensure_dir('pacman_salt_cache_dir', '/var/cache/salt', mode='0755', user='root') }}

etckeeper_init:
  cmd.run:
    - name: etckeeper init && etckeeper commit "Initial commit"
    - unless: test -d /etc/.git
    - onlyif: command -v etckeeper

desktop_services_enabled:
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

# pcscd is socket-activated: scdaemon connects on demand for Yubikey smart card operations.
pcscd_socket_enabled:
  service.enabled:
    - name: pcscd.socket

# Disable tuned: its throughput-performance profile conflicts with custom
# I/O tuning (sets read_ahead_kb=8192 on NVMe, may override sysctl values).
# All tuning is managed manually via sysctl.sls, kernel_params_limine.sls, hardware.sls.
{{ service_stopped('tuned_stopped', 'tuned') }}

# --- Hyprland ecosystem packages ---
{{ pacman_install('hyprland_desktop',
    'hyprpaper hypridle hyprlock hyprpolkitagent xdg-desktop-portal-hyprland hyprpicker wlr-randr') }}
{{ pacman_install('screenshot_tools', 'grim slurp') }}
{{ pacman_install('rsync', 'rsync') }}
{{ pacman_install('localsend', 'localsend') }}

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
dconf_themes:
  cmd.run:
    - name: |
        set -eo pipefail
{% for key, val in desktop.dconf_settings.items() %}
{%- set safe = val | replace('\\', '\\\\') | replace('"', '\\"') | replace('`', '\\`') | replace('$', '\\$') %}
        dconf write {{ key }} "'{{ safe }}'"
{% endfor %}
    - runas: {{ user }}
    - env:
      - DBUS_SESSION_BUS_ADDRESS: "unix:path={{ host.runtime_dir }}/bus"
    - unless: |
        export DBUS_SESSION_BUS_ADDRESS=unix:path={{ host.runtime_dir }}/bus
{% for key, val in desktop.dconf_settings.items() %}
{%- set safe = val | replace('\\', '\\\\') | replace('"', '\\"') | replace('`', '\\`') | replace('$', '\\$') %}
        test "$(dconf read {{ key }})" = "'{{ safe }}'"{{ ' &&' if not loop.last else '' }}
{% endfor %}

# --- Salt daemon systemd unit ---
salt_daemon_service:
  file.managed:
    - name: /etc/systemd/system/salt-daemon.service
    - source: salt://units/salt-daemon.service.j2
    - template: jinja
    - context:
        project_dir: {{ host.project_dir }}
    - mode: '0644'
