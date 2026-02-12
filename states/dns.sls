{% from 'host_config.jinja' import host %}
{% set dns = host.features.dns %}

# --- Unbound: recursive DNS resolver with DNSSEC + DoT ---
{% if dns.unbound %}
install_unbound:
  cmd.run:
    - name: rpm-ostree install --idempotent --apply-live unbound
    - unless: rpm -q unbound

unbound_config:
  file.managed:
    - name: /etc/unbound/unbound.conf
    - makedirs: True
    - mode: '0644'
    - contents: |
        server:
            interface: 127.0.0.1
            port: 5353
            do-tcp: yes
            do-udp: yes
            so-reuseport: yes
            edns-buffer-size: 1232

            # DNSSEC
            auto-trust-anchor-file: /var/lib/unbound/root.key
            val-permissive-mode: no
            harden-dnssec-stripped: yes
            harden-glue: yes
            harden-below-nxdomain: yes

            # Privacy + performance
            qname-minimisation: yes
            minimal-responses: yes
            prefetch: yes
            prefetch-key: yes
            aggressive-nsec: yes

            # Serve stale data while refreshing
            serve-expired: yes
            serve-expired-ttl: 3600
            serve-expired-reply-ttl: 30

            # TLS cert bundle for DoT
            tls-cert-bundle: /etc/pki/tls/certs/ca-bundle.crt

            # Statistics for exporters
            extended-statistics: yes
            statistics-interval: 0
            statistics-cumulative: yes

            # Logging
            verbosity: 1
            log-queries: no
            log-replies: no
            log-local-actions: no
            log-servfail: no

        # Allow unbound-control without TLS certs
        remote-control:
            control-enable: yes
            control-interface: 127.0.0.1
            control-port: 8953
            control-use-cert: no

        # Forward all queries via DNS-over-TLS
        forward-zone:
            name: "."
            forward-tls-upstream: yes
            forward-addr: 1.1.1.1@853#cloudflare-dns.com
            forward-addr: 1.0.0.1@853#cloudflare-dns.com
            forward-addr: 9.9.9.9@853#dns.quad9.net
            forward-addr: 149.112.112.112@853#dns.quad9.net

unbound_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - cmd: install_unbound

unbound_enabled:
  service.enabled:
    - name: unbound
    - require:
      - file: unbound_config
      - cmd: unbound_daemon_reload
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
    - contents: |
        http:
          pprof:
            port: 6060
            enabled: false
          address: 127.0.0.1:3000
          session_ttl: 720h
        dns:
          bind_hosts:
            - 127.0.0.1
          port: 53
          upstream_dns:
            - 127.0.0.1:5353
          bootstrap_dns:
            - 1.1.1.1
            - 8.8.8.8
          enable_dnssec: false
          cache_size: 4194304
          cache_ttl_min: 0
          cache_ttl_max: 0
          cache_optimistic: true
          upstream_mode: parallel
        filtering:
          protection_enabled: true
          filtering_enabled: true
          parental_enabled: false
          safebrowsing_enabled: false
          safe_search:
            enabled: false
        filters:
          - enabled: true
            url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
            name: AdGuard DNS filter
            id: 1
          - enabled: true
            url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
            name: AdAway Default Blocklist
            id: 2
        user_rules: []
        schema_version: 29
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

adguardhome_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: adguardhome_service

adguardhome_enabled:
  service.enabled:
    - name: adguardhome
    - require:
      - file: adguardhome_service
      - cmd: install_adguardhome
      - file: adguardhome_config

# Configure systemd-resolved to forward to AdGuardHome
resolved_adguardhome:
  file.managed:
    - name: /etc/systemd/resolved.conf.d/adguardhome.conf
    - makedirs: True
    - mode: '0644'
    - contents: |
        [Resolve]
        DNS=127.0.0.1
        Domains=~.
        LLMNR=no
        MulticastDNS=no

resolved_restart:
  cmd.run:
    - name: systemctl restart systemd-resolved
    - onchanges:
      - file: resolved_adguardhome
{% endif %}

# --- Avahi: mDNS/Bonjour local service discovery ---
{% if dns.avahi %}
install_avahi:
  cmd.run:
    - name: rpm-ostree install --idempotent --apply-live avahi avahi-tools nss-mdns
    - unless: rpm -q avahi

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
