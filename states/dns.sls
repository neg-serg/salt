{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload, ostree_install %}
{% set dns = host.features.dns %}

# --- Unbound: recursive DNS resolver with DNSSEC + DoT ---
{% if dns.unbound %}
{{ ostree_install('unbound', 'unbound') }}

unbound_config:
  file.managed:
    - name: /etc/unbound/unbound.conf
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/unbound.conf

unbound_selinux_port:
  cmd.run:
    - name: |
        semanage port -a -t dns_port_t -p tcp 5353 2>/dev/null || semanage port -m -t dns_port_t -p tcp 5353
        semanage port -a -t dns_port_t -p udp 5353 2>/dev/null || semanage port -m -t dns_port_t -p udp 5353
    - unless: semanage port -l | grep dns_port_t | grep -q 5353
    - require:
      - cmd: install_unbound

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
      - cmd: unbound_selinux_port
{% endif %}

# --- AdGuardHome: DNS filtering + ad blocking ---
{% if dns.adguardhome %}
install_adguardhome:
  cmd.run:
    - name: |
        TAG=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | jq -r .tag_name)
        VER=${TAG#v}
        curl -sL "https://github.com/AdguardTeam/AdGuardHome/releases/download/${TAG}/AdGuardHome_linux_amd64.tar.gz" -o /tmp/adguardhome.tar.gz
        tar -xzf /tmp/adguardhome.tar.gz -C /tmp
        install -m 0755 /tmp/AdGuardHome/AdGuardHome /usr/local/bin/adguardhome
        rm -rf /tmp/adguardhome.tar.gz /tmp/AdGuardHome
    - creates: /usr/local/bin/adguardhome

adguardhome_user:
  user.present:
    - name: adguardhome
    - system: True
    - shell: /usr/sbin/nologin
    - home: /var/lib/adguardhome
    - createhome: False

adguardhome_data_dir:
  file.directory:
    - name: /var/lib/adguardhome
    - user: adguardhome
    - group: adguardhome
    - makedirs: True
    - require:
      - user: adguardhome_user

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
    - contents: |
        [Unit]
        Description=AdGuard Home DNS filter
        After=network-online.target{% if dns.unbound %} unbound.service{% endif %}

        Wants=network-online.target
{% if dns.unbound %}
        Requires=unbound.service
{% endif %}

        [Service]
        Type=simple
        User=adguardhome
        Group=adguardhome
        WorkingDirectory=/var/lib/adguardhome
        ExecStart=/usr/local/bin/adguardhome --no-check-update -w /var/lib/adguardhome
        Restart=on-failure
        RestartSec=5
        AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_RAW
        CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW

        [Install]
        WantedBy=multi-user.target

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
{{ ostree_install('avahi', 'avahi avahi-tools nss-mdns') }}

avahi_config:
  file.managed:
    - name: /etc/avahi/avahi-daemon.conf
    - makedirs: True
    - mode: '0644'
    - contents: |
        [server]
        use-ipv4=yes
        use-ipv6=yes
        allow-interfaces=
        deny-interfaces=
        ratelimit-interval-usec=1000000
        ratelimit-burst=1000

        [wide-area]
        enable-wide-area=yes

        [publish]
        publish-hinfo=no
        publish-workstation=yes
        publish-domain=yes
        publish-addresses=yes

avahi_enabled:
  service.enabled:
    - name: avahi-daemon
    - require:
      - file: avahi_config
{% endif %}
