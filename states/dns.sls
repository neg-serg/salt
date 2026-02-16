{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload, pacman_install, system_daemon_user, github_release_system %}
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
  cmd.run:
    - name: systemctl enable unbound
    - onlyif: systemctl list-unit-files unbound.service | grep -q unbound
    - require:
      - cmd: install_unbound
      - file: unbound_config
      - cmd: unbound_daemon_reload
      - cmd: unbound_root_key

unbound_reset_failed:
  cmd.run:
    - name: systemctl reset-failed unbound 2>/dev/null; true
    - onlyif: systemctl is-failed unbound
    - require:
      - cmd: unbound_enabled

unbound_running:
  service.running:
    - name: unbound
    - watch:
      - file: unbound_config
      - file: unbound_restart_override
    - require:
      - cmd: unbound_enabled
      - cmd: unbound_reset_failed
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

adguardhome_service:
  file.managed:
    - name: /etc/systemd/system/adguardhome.service
    - mode: '0644'
    - source: salt://units/adguardhome.service.j2
    - template: jinja
    - context:
        dns_unbound: {{ dns.unbound }}

{{ daemon_reload('adguardhome', ['file: adguardhome_service']) }}

adguardhome_enabled:
  service.enabled:
    - name: adguardhome
    - require:
      - file: adguardhome_service
      - cmd: install_adguardhome
      - file: adguardhome_config
      - cmd: adguardhome_daemon_reload

adguardhome_reset_failed:
  cmd.run:
    - name: systemctl reset-failed adguardhome 2>/dev/null; true
    - onlyif: systemctl is-failed adguardhome
    - require:
      - service: adguardhome_enabled

adguardhome_running:
  service.running:
    - name: adguardhome
    - watch:
      - file: adguardhome_service
    - require:
      - service: adguardhome_enabled
      - cmd: adguardhome_reset_failed

# Configure systemd-resolved to forward to AdGuardHome
resolved_adguardhome:
  file.managed:
    - name: /etc/systemd/resolved.conf.d/adguardhome.conf
    - makedirs: True
    - mode: '0644'
    - contents: |
        [Resolve]
        DNS=127.0.0.1
        FallbackDNS=1.1.1.1 9.9.9.9 8.8.8.8
        Domains=~.
        LLMNR=no
        MulticastDNS=no
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
