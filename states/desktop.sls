# Desktop environment: services, SSH, dconf themes
{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval %}
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_stopped, service_with_unit %}
{% from '_macros_desktop.jinja' import dconf_settings, hyprpm_add, hyprpm_enable, hyprpm_update %}
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

# libvirtd: socket-activated only. The service must be DISABLED so systemd doesn't
# start the full daemon at boot (1.2s on critical path). The socket starts it
# on-demand when a client connects; autostart VMs still trigger activation.
{{ pacman_install('libvirt', 'libvirt') }}

libvirtd_service_disabled:
  service.disabled:
    - name: libvirtd
    - require:
      - cmd: install_libvirt

libvirtd_socket_enabled:
  service.enabled:
    - name: libvirtd.socket
    - require:
      - cmd: install_libvirt
      - service: libvirtd_service_disabled

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

{{ hyprpm_update('hyprpm_headers_update',
    check_plugins=['xtra-dispatchers', 'HyprGlass'],
    require=['cmd: install_hyprland_desktop', 'file: hyprpm_cache_dir']) }}

# hyprpm add + enable are separate: add is guarded by repo presence,
# enable is guarded by "enabled: <ANSI>true" in hyprpm list output.
{{ hyprpm_add('hyprpm_add_hyprland_plugins',
    'https://github.com/hyprwm/hyprland-plugins',
    'Repository hyprland-plugins',
    require=['cmd: install_hyprland_desktop', 'cmd: hyprpm_headers_update', 'file: hyprpm_repo_cache_hyprland_plugins']) }}

{{ hyprpm_enable('hyprpm_enable_xtra_dispatchers',
    'xtra-dispatchers',
    require=['cmd: hyprpm_add_hyprland_plugins']) }}

{{ hyprpm_add('hyprpm_add_hyprglass',
    'https://github.com/hyprnux/hyprglass',
    'Repository HyprGlass',
    require=['cmd: install_hyprland_desktop', 'cmd: hyprpm_headers_update', 'file: hyprpm_repo_cache_hyprglass']) }}

{{ hyprpm_enable('hyprpm_enable_hyprglass',
    'hyprglass',
    require=['cmd: hyprpm_add_hyprglass']) }}

# --- SSH directory setup ---
{{ ensure_dir('ssh_dir', home ~ '/.ssh', mode='0700') }}


# --- dconf: GTK/icon/font theme for Wayland apps ---
{{ dconf_settings('dconf_themes', desktop.dconf_settings) }}

# --- Salt daemon systemd unit ---
salt_daemon_venv_ready:
  file.exists:
    - name: {{ host.project_dir }}/.venv/bin/python3

{{ service_with_unit('salt-daemon', 'salt://units/salt-daemon.service.j2', template='jinja', context={'project_dir': host.project_dir}, running=True, requires=['file: salt_daemon_venv_ready']) }}
