{% from '_imports.jinja' import host %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% from '_macros_service.jinja' import ensure_running, service_with_healthcheck, service_with_unit, unit_override %}
{% from '_macros_pkg.jinja' import simple_service, pacman_install %}
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

unbound_confd:
  file.directory:
    - name: /etc/unbound/unbound.conf.d
    - mode: '0755'
    - require:
      - cmd: install_unbound

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

{{ service_with_healthcheck('unbound_ready', 'unbound', catalog=catalog, requires=['service: unbound_running']) }}

# Reusable restart target for external configs (e.g. tailscale DNS stub)
# that drop files into unbound.conf.d/ and need unbound to pick them up.
unbound_restart_or_reload:
  cmd.run:
    - name: unbound-control reload 2>/dev/null || systemctl restart unbound 2>/dev/null || true
{% endif %}

# --- AdGuardHome: DNS filtering + ad blocking ---
{% if dns.adguardhome %}
{{ pacman_install('adguardhome', 'adguardhome') }}

# One-time cleanup: remove old manually-installed binary
adguardhome_legacy_cleanup:
  file.absent:
    - name: /usr/local/bin/AdGuardHome
    - onlyif: test -f /usr/local/bin/AdGuardHome

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
      - cmd: managed_service_accounts_ensure
      - cmd: managed_service_paths_ensure

{{ service_with_unit('adguardhome', 'salt://units/adguardhome.service.j2', template='jinja', context={'dns_unbound': dns.unbound}, requires=['cmd: install_adguardhome', 'file: adguardhome_config', 'cmd: managed_service_accounts_ensure', 'cmd: managed_service_paths_ensure'], running=True, watch=['file: adguardhome_config']) }}

{{ service_with_healthcheck('adguardhome_start', 'adguardhome', catalog=catalog, requires=['service: adguardhome_enabled']) }}

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
