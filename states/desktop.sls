# Desktop environment: services, SSH, dconf themes
{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_stopped, service_with_unit %}
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

# --- Faillock: raise threshold to avoid lockouts on typos ---
faillock_config:
  file.replace:
    - name: /etc/security/faillock.conf
    - pattern: '^#?\s*deny\s*=\s*\d+'
    - repl: 'deny = 10'

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
{{ pacman_install('libvirt', 'libvirt') }}

libvirtd_enabled:
  service.enabled:
    - name: libvirtd
    - require:
      - cmd: install_libvirt

# pcscd is socket-activated: scdaemon connects on demand for Yubikey smart card operations.
{{ pacman_install('pcsclite', 'pcsclite') }}

pcscd_socket_enabled:
  service.enabled:
    - name: pcscd.socket
    - require:
      - cmd: install_pcsclite

# Disable tuned: its throughput-performance profile conflicts with custom
# I/O tuning (sets read_ahead_kb=8192 on NVMe, may override sysctl values).
# All tuning is managed manually via sysctl.sls, kernel_params_limine.sls, hardware.sls.
{{ service_stopped('tuned_stopped', 'tuned', onlyif='systemctl list-unit-files tuned.service 2>/dev/null | rg -q tuned') }}

# --- Hyprland ecosystem packages ---
{{ pacman_install('hyprland_desktop', desktop.hyprland_packages | join(' ')) }}
{{ pacman_install('screenshot_tools', desktop.screenshot_packages | join(' ')) }}
{{ pacman_install('rsync', 'rsync') }}
{{ pacman_install('localsend', 'localsend') }}
{{ pacman_install('chromium', 'chromium') }}

{{ paru_install('xdg-termfilechooser', 'xdg-desktop-portal-termfilechooser-boydaihungst-git') }}

{{ paru_install('wlr-which-key', 'wlr-which-key') }}

# --- swayimg: use local build from ~/src/swayimg instead of pacman binary ---
swayimg_local_build:
  file.symlink:
    - name: {{ home }}/.local/bin/swayimg
    - target: {{ home }}/src/swayimg/build/swayimg
    - force: True
    - user: {{ user }}
    - group: {{ user }}

# wl: installed via custom_pkgs (PKGBUILD → /usr/bin/)

# --- SSH directory setup ---
{{ ensure_dir('ssh_dir', home ~ '/.ssh', mode='0700') }}


# --- dconf: GTK/icon/font theme for Wayland apps ---
dconf_themes:
  cmd.run:
    - name: |
        set -eo pipefail
{% for key, val in desktop.dconf_settings.items() %}
{%- set safe = val | replace('\\', '\\\\') | replace('"', '\\"') | replace('`', '\\`') | replace('$', '\\$') %}
        dconf write {{ key }} "'{{ safe }}'"
{% endfor %}
    - shell: /bin/bash
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
salt_daemon_venv_ready:
  file.exists:
    - name: {{ host.project_dir }}/.venv/bin/python3

{{ service_with_unit('salt-daemon', 'salt://units/salt-daemon.service.j2', template='jinja', context={'project_dir': host.project_dir}, running=True, requires=['file: salt_daemon_venv_ready']) }}
