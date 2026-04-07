# Desktop environment: services, SSH, dconf themes
{% from '_imports.jinja' import user, home %}
{% from '_macros_pkg.jinja' import pacman_install %}
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

# --- SSH hardening: keys only, no passwords, no root login ---
sshd_hardening:
  file.managed:
    - name: /etc/ssh/sshd_config.d/10-hardening.conf
    - source: salt://configs/sshd-hardening.conf
    - mode: '0644'

sshd_authorized_keys:
  cmd.run:
    - name: |
        install -m 0600 -o {{ user }} -g {{ user }} /dev/null {{ home }}/.ssh/authorized_keys
        cat {{ home }}/.ssh/id_ed25519.pub > {{ home }}/.ssh/authorized_keys
    - unless: test -s {{ home }}/.ssh/authorized_keys && grep -qF "$(cat {{ home }}/.ssh/id_ed25519.pub)" {{ home }}/.ssh/authorized_keys
    - onlyif: test -f {{ home }}/.ssh/id_ed25519.pub
    - require:
      - file: ssh_dir

sshd_restart:
  service.running:
    - name: sshd
    - watch:
      - file: sshd_hardening

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
{{ service_stopped('tuned_stopped', 'tuned', onlyif='systemctl list-unit-files tuned.service 2>/dev/null | grep -q tuned') }}
