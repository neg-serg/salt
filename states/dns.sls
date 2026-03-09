{% from '_imports.jinja' import host, service_ports %}
{% from '_macros_service.jinja' import unit_override, system_daemon_user, service_with_unit, service_with_healthcheck, ensure_running %}
{% from '_macros_github.jinja' import github_release_system %}
{% from '_macros_pkg.jinja' import simple_service %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set dns = host.features.dns %}

# --- Unbound: recursive DNS resolver with DNSSEC + DoT ---
{% if dns.unbound %}
{{ simple_service('unbound', 'unbound', requires=['file: unbound_config', 'cmd: unbound_restart_override_reload', 'cmd: unbound_root_key', 'cmd: unbound_control_certs']) }}

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

unbound_control_certs:
  cmd.run:
    - name: unbound-control-setup
    - creates: /etc/unbound/unbound_server.pem
    - require:
      - cmd: install_unbound

{{ unit_override('unbound_restart_override', 'unbound.service', 'salt://units/unbound-restart-override.conf', filename='restart.conf', requires=['cmd: install_unbound']) }}

{{ ensure_running('unbound', watch=['file: unbound_config', 'file: unbound_restart_override']) }}

{{ service_with_healthcheck('unbound_ready', 'unbound', 'unbound-control status >/dev/null 2>&1', requires=['service: unbound_running']) }}
{% endif %}

# --- AdGuardHome: DNS filtering + ad blocking ---
{% if dns.adguardhome %}
{{ github_release_system('adguardhome', 'AdguardTeam/AdGuardHome', 'AdGuardHome_linux_amd64.tar.gz', src_bin='AdGuardHome', format='tar.gz', tag='v' ~ ver.get('adguardhome', ''), hash='cf25794597a2f5b6cd8cd3670439db6f548c59af4ace392e40055b90e80c9329', version=ver.get('adguardhome', '')) }}
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

{{ service_with_unit('adguardhome', 'salt://units/adguardhome.service.j2', template='jinja', context={'dns_unbound': dns.unbound}, requires=['cmd: install_adguardhome', 'file: adguardhome_config'], running=True, watch=['file: adguardhome_config']) }}

{{ service_with_healthcheck('adguardhome_start', 'adguardhome', 'curl -sf http://127.0.0.1:' ~ service_ports.adguardhome.port ~ service_ports.adguardhome.healthcheck ~ ' >/dev/null 2>&1', requires=['service: adguardhome_enabled']) }}

# Configure systemd-resolved to forward to AdGuardHome
resolved_adguardhome:
  file.managed:
    - name: /etc/systemd/resolved.conf.d/adguardhome.conf
    - source: salt://configs/resolved-adguardhome.conf
    - makedirs: True
    - mode: '0644'
    - require:
      - cmd: adguardhome_start
{% if dns.unbound %}
      - cmd: unbound_ready
{% endif %}

resolved_restart:
  service.running:
    - name: systemd-resolved
    - watch:
      - file: resolved_adguardhome
{% endif %}

# --- Avahi: mDNS/Bonjour local service discovery ---
{% if dns.avahi %}
{{ simple_service('avahi', 'avahi avahi-tools nss-mdns', service='avahi-daemon', requires=['file: avahi_config']) }}

avahi_config:
  file.managed:
    - name: /etc/avahi/avahi-daemon.conf
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/avahi-daemon.conf

{{ ensure_running('avahi', service='avahi-daemon', watch=['file: avahi_config']) }}
{% endif %}
