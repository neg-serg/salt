{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload %}
{% set svc = host.features.services %}

# --- Samba: SMB file sharing (manual start) ---
{% if svc.samba %}
install_samba:
  cmd.run:
    - name: rpm-ostree install --idempotent --apply-live samba
    - unless: rpm -q samba

samba_share_dir:
  file.directory:
    - name: /mnt/zero/sync/smb
    - mode: '0777'
    - makedirs: True

samba_config:
  file.managed:
    - name: /etc/samba/smb.conf
    - makedirs: True
    - mode: '0644'
    - contents: |
        [global]
        workgroup = WORKGROUP
        server string = {{ host.hostname }} Samba Server
        netbios name = {{ host.hostname }}
        map to guest = Bad User
        security = user

        [shared]
        path = /mnt/zero/sync/smb
        browseable = yes
        read only = no
        guest ok = yes

# Don't enable at boot — manual start only: systemctl start smb
samba_not_enabled:
  service.disabled:
    - name: smb
    - require:
      - file: samba_config
{% endif %}

# --- Jellyfin: media server ---
{% if svc.jellyfin %}
jellyfin_repo:
  file.managed:
    - name: /etc/yum.repos.d/jellyfin.repo
    - contents: |
        [jellyfin]
        name=Jellyfin
        baseurl=https://repo.jellyfin.org/releases/server/fedora/stable/$basearch
        gpgcheck=1
        gpgkey=https://repo.jellyfin.org/releases/server/fedora/stable/RPM-GPG-KEY-jellyfin-server
        enabled=1
    - mode: '0644'

install_jellyfin:
  cmd.run:
    - name: rpm-ostree install --idempotent --apply-live jellyfin-server jellyfin-web
    - unless: rpm -q jellyfin-server
    - require:
      - file: jellyfin_repo

jellyfin_enabled:
  service.enabled:
    - name: jellyfin
    - require:
      - cmd: install_jellyfin
{% endif %}

# --- Bitcoind: Bitcoin Core node ---
{% if svc.bitcoind %}
install_bitcoind:
  cmd.run:
    - name: |
        VER=28.1
        curl -sL "https://bitcoincore.org/bin/bitcoin-core-${VER}/bitcoin-${VER}-x86_64-linux-gnu.tar.gz" -o /tmp/bitcoin.tar.gz
        tar -xzf /tmp/bitcoin.tar.gz -C /tmp
        install -m 0755 /tmp/bitcoin-${VER}/bin/bitcoind /usr/local/bin/bitcoind
        install -m 0755 /tmp/bitcoin-${VER}/bin/bitcoin-cli /usr/local/bin/bitcoin-cli
        rm -rf /tmp/bitcoin.tar.gz /tmp/bitcoin-${VER}
    - creates: /usr/local/bin/bitcoind

bitcoind_user:
  user.present:
    - name: bitcoind
    - system: True
    - shell: /usr/sbin/nologin
    - home: /var/lib/bitcoind
    - createhome: False

bitcoind_data_dir:
  file.directory:
    - name: /var/lib/bitcoind
    - user: bitcoind
    - group: bitcoind
    - makedirs: True
    - require:
      - user: bitcoind_user

bitcoind_service:
  file.managed:
    - name: /etc/systemd/system/bitcoind.service
    - mode: '0644'
    - contents: |
        [Unit]
        Description=Bitcoin Core daemon
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        User=bitcoind
        Group=bitcoind
        ExecStart=/usr/local/bin/bitcoind -datadir=/var/lib/bitcoind -printtoconsole=1 -shrinkdebugfile=1
        Restart=on-failure
        RestartSec=30

        [Install]
        WantedBy=multi-user.target

bitcoind_logrotate:
  file.managed:
    - name: /etc/logrotate.d/bitcoind
    - mode: '0644'
    - contents: |
        /var/lib/bitcoind/debug.log {
            weekly
            rotate 8
            missingok
            compress
            delaycompress
            copytruncate
            size 50M
            su bitcoind bitcoind
        }

{{ daemon_reload('bitcoind', ['file: bitcoind_service']) }}

# Don't enable at boot — manual start: systemctl start bitcoind
bitcoind_not_enabled:
  service.disabled:
    - name: bitcoind
    - require:
      - file: bitcoind_service
{% endif %}

# --- DuckDNS: dynamic DNS updater ---
{% if svc.duckdns %}
duckdns_script:
  file.managed:
    - name: /usr/local/bin/duckdns-update
    - mode: '0755'
    - contents: |
        #!/usr/bin/env bash
        # Requires DUCKDNS_TOKEN and DUCKDNS_DOMAIN in environment
        set -eu
        : "${DUCKDNS_TOKEN:?DUCKDNS_TOKEN not set}"
        : "${DUCKDNS_DOMAIN:?DUCKDNS_DOMAIN not set}"
        curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip="

duckdns_service:
  file.managed:
    - name: /etc/systemd/system/duckdns-update.service
    - mode: '0644'
    - contents: |
        [Unit]
        Description=DuckDNS IP update
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=oneshot
        EnvironmentFile=/etc/duckdns.env
        ExecStart=/usr/local/bin/duckdns-update

duckdns_timer:
  file.managed:
    - name: /etc/systemd/system/duckdns-update.timer
    - mode: '0644'
    - contents: |
        [Unit]
        Description=DuckDNS periodic IP update

        [Timer]
        OnCalendar=*:0/5
        Persistent=true

        [Install]
        WantedBy=timers.target

{{ daemon_reload('duckdns', ['file: duckdns_service', 'file: duckdns_timer']) }}

# Timer disabled by default — enable after creating /etc/duckdns.env
duckdns_not_enabled:
  service.disabled:
    - name: duckdns-update.timer
    - require:
      - file: duckdns_timer
{% endif %}
