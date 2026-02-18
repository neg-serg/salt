{% from 'host_config.jinja' import host %}
{% from '_macros_service.jinja' import daemon_reload, system_daemon_user, service_with_unit, ensure_running %}
{% from '_macros_install.jinja' import github_release_system %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% set dns = host.features.dns %}

# --- Unbound: recursive DNS resolver with DNSSEC + DoT ---
{% if dns.unbound %}
{{ pacman_install('unbound', 'unbound') }}

unbound_config:
  file.managed:
    - name: /etc/unbound/unbound.conf
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/unbound.conf

unbound_root_key:
  cmd.run:
    - name: unbound-anchor -a /var/lib/unbound/root.key || true
    - creates: /var/lib/unbound/root.key
    - require:
      - cmd: install_unbound

unbound_restart_override:
  file.managed:
    - name: /etc/systemd/system/unbound.service.d/restart.conf
    - makedirs: True
    - mode: '0644'
    - contents: |
        [Service]
        Restart=on-failure
        RestartSec=5
    - require:
      - cmd: install_unbound

{{ daemon_reload('unbound', ['cmd: install_unbound', 'file: unbound_restart_override']) }}

unbound_enabled:
  service.enabled:
    - name: unbound
    - require:
      - cmd: install_unbound
      - file: unbound_config
      - cmd: unbound_daemon_reload
      - cmd: unbound_root_key

{{ ensure_running('unbound', watch=['file: unbound_config', 'file: unbound_restart_override']) }}
{% endif %}

# --- AdGuardHome: DNS filtering + ad blocking ---
{% if dns.adguardhome %}
{{ github_release_system('adguardhome', 'AdguardTeam/AdGuardHome', 'AdGuardHome_linux_amd64.tar.gz', src_bin='AdGuardHome', format='tar.gz') }}
{{ system_daemon_user('adguardhome', '/var/lib/adguardhome') }}

adguardhome_config:
  file.managed:
    - name: /var/lib/adguardhome/AdGuardHome.yaml
    - user: adguardhome
    - group: adguardhome
    - mode: '0640'
    - makedirs: True
    - replace: False
    - source: salt://configs/adguardhome-initial.yaml
    - require:
      - file: adguardhome_data_dir

{{ service_with_unit('adguardhome', 'salt://units/adguardhome.service.j2', template='jinja', context={'dns_unbound': dns.unbound}, requires=['cmd: install_adguardhome', 'file: adguardhome_config'], running=True) }}

# Configure systemd-resolved to forward to AdGuardHome
resolved_adguardhome:
  file.managed:
    - name: /etc/systemd/resolved.conf.d/adguardhome.conf
    - source: salt://configs/resolved-adguardhome.conf
    - makedirs: True
    - mode: '0644'
    - require:
      - service: adguardhome_running
{% if dns.unbound %}
      - service: unbound_running
{% endif %}

resolved_restart:
  cmd.run:
    - name: systemctl restart systemd-resolved
    - onchanges:
      - file: resolved_adguardhome
{% endif %}

# --- Avahi: mDNS/Bonjour local service discovery ---
{% if dns.avahi %}
{{ pacman_install('avahi', 'avahi avahi-tools nss-mdns') }}

avahi_config:
  file.managed:
    - name: /etc/avahi/avahi-daemon.conf
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/avahi-daemon.conf

avahi_enabled:
  service.enabled:
    - name: avahi-daemon
    - require:
      - file: avahi_config
{% endif %}
