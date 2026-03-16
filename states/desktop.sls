# Desktop environment: services, SSH, dconf themes
{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval %}
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

# --- Hyprland plugins via hyprpm ---
# hyprpm needs HYPRLAND_INSTANCE_SIGNATURE (detect from socket dir) and
# headers must match the running Hyprland version (hyprpm update rebuilds them).
# hyprpm writes state to /var/cache/hyprpm/<user>/; ensure user ownership so
# hyprpm doesn't need sudo (which fails without a TTY in Salt context).
{% set hypr_sig_cmd = 'ls /run/user/1000/hypr/ 2>/dev/null | head -1' %}
{% set hyprpm_cache = '/var/cache/hyprpm/' ~ user %}

hyprpm_cache_dir:
  file.directory:
    - name: {{ hyprpm_cache }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
    - recurse:
      - user
      - group

# Pre-create repo cache dirs so hyprpm doesn't call sudo mkdir (which fails
# without a TTY in Salt context).
hyprpm_repo_cache_hyprland_plugins:
  file.directory:
    - name: {{ hyprpm_cache }}/hyprland-plugins
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hyprpm_cache_dir

hyprpm_repo_cache_hyprglass:
  file.directory:
    - name: {{ hyprpm_cache }}/HyprGlass
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hyprpm_cache_dir

hyprpm_headers_update:
  cmd.run:
    - name: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm update
    - runas: {{ user }}
    - onlyif: ls /run/user/1000/hypr/ 2>/dev/null | rg -q .
    - unless: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm list 2>&1 | rg -q 'xtra-dispatchers' &&
        hyprpm list 2>&1 | rg -q 'HyprGlass'
    - env:
      - HOME: {{ home }}
      - XDG_RUNTIME_DIR: /run/user/1000
    - require:
      - cmd: install_hyprland_desktop
      - file: hyprpm_cache_dir
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - timeout: 300

# hyprpm add + enable are separate: add is guarded by repo presence,
# enable is guarded by "enabled: <ANSI>true" in hyprpm list output.
{% set hyprpm_env %}
      - HOME: {{ home }}
      - XDG_RUNTIME_DIR: /run/user/1000
{% endset %}
{% set hyprpm_onlyif = 'ls /run/user/1000/hypr/ 2>/dev/null | rg -q .' %}

hyprpm_add_hyprland_plugins:
  cmd.run:
    - name: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        yes | hyprpm add https://github.com/hyprwm/hyprland-plugins
    - runas: {{ user }}
    - onlyif: {{ hyprpm_onlyif }}
    - unless: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm list 2>&1 | rg -q 'Repository hyprland-plugins'
    - env:
{{ hyprpm_env }}
    - require:
      - cmd: install_hyprland_desktop
      - cmd: hyprpm_headers_update
      - file: hyprpm_repo_cache_hyprland_plugins
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - timeout: 300

hyprpm_enable_xtra_dispatchers:
  cmd.run:
    - name: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm enable xtra-dispatchers
    - runas: {{ user }}
    - onlyif: {{ hyprpm_onlyif }}
    - unless: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm list 2>&1 | rg 'xtra-dispatchers' -A1 | rg -q 'enabled:.*true'
    - env:
{{ hyprpm_env }}
    - require:
      - cmd: hyprpm_add_hyprland_plugins

hyprpm_add_hyprglass:
  cmd.run:
    - name: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        yes | hyprpm add https://github.com/hyprnux/hyprglass
    - runas: {{ user }}
    - onlyif: {{ hyprpm_onlyif }}
    - unless: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm list 2>&1 | rg -q 'Repository HyprGlass'
    - env:
{{ hyprpm_env }}
    - require:
      - cmd: install_hyprland_desktop
      - cmd: hyprpm_headers_update
      - file: hyprpm_repo_cache_hyprglass
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - timeout: 300

hyprpm_enable_hyprglass:
  cmd.run:
    - name: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm enable hyprglass
    - runas: {{ user }}
    - onlyif: {{ hyprpm_onlyif }}
    - unless: >-
        export HYPRLAND_INSTANCE_SIGNATURE=$( {{ hypr_sig_cmd }} ) &&
        hyprpm list 2>&1 | rg 'hyprglass' -A1 | rg -q 'enabled:.*true'
    - env:
{{ hyprpm_env }}
    - require:
      - cmd: hyprpm_add_hyprglass

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
