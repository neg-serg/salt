{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload, pacman_install, system_daemon_user, service_with_unit %}
{% set svc = host.features.services %}
{% set bitcoind_ver = '28.1' %}

# --- Samba: SMB file sharing (manual start) ---
{% if svc.samba %}
{{ pacman_install('samba', 'samba') }}

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
    - source: salt://configs/smb.conf.j2
    - template: jinja
    - context:
        hostname: {{ host.hostname }}

# Don't enable at boot — manual start only: systemctl start smb
samba_not_enabled:
  service.disabled:
    - name: smb
    - require:
      - file: samba_config
{% endif %}

# --- Jellyfin: media server ---
{% if svc.jellyfin %}
{{ pacman_install('jellyfin', 'jellyfin-server jellyfin-web') }}

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
        curl -sL "https://bitcoincore.org/bin/bitcoin-core-{{ bitcoind_ver }}/bitcoin-{{ bitcoind_ver }}-x86_64-linux-gnu.tar.gz" -o /tmp/bitcoin.tar.gz
        tar -xzf /tmp/bitcoin.tar.gz -C /tmp
        install -m 0755 /tmp/bitcoin-{{ bitcoind_ver }}/bin/bitcoind /usr/local/bin/bitcoind
        install -m 0755 /tmp/bitcoin-{{ bitcoind_ver }}/bin/bitcoin-cli /usr/local/bin/bitcoin-cli
        rm -rf /tmp/bitcoin.tar.gz /tmp/bitcoin-{{ bitcoind_ver }}
    - creates: /usr/local/bin/bitcoind

{{ system_daemon_user('bitcoind', '/var/lib/bitcoind') }}

# Don't enable at boot — manual start: systemctl start bitcoind
{{ service_with_unit('bitcoind', 'salt://units/bitcoind.service', enabled=False) }}

bitcoind_logrotate:
  file.managed:
    - name: /etc/logrotate.d/bitcoind
    - mode: '0644'
    - source: salt://configs/bitcoind-logrotate
{% endif %}

# --- DuckDNS: dynamic DNS updater ---
{% if svc.duckdns %}
duckdns_script:
  file.managed:
    - name: /usr/local/bin/duckdns-update
    - mode: '0755'
    - source: salt://scripts/duckdns-update.sh

duckdns_service:
  file.managed:
    - name: /etc/systemd/system/duckdns-update.service
    - mode: '0644'
    - source: salt://units/duckdns-update.service

duckdns_timer:
  file.managed:
    - name: /etc/systemd/system/duckdns-update.timer
    - mode: '0644'
    - source: salt://units/duckdns-update.timer

{{ daemon_reload('duckdns', ['file: duckdns_service', 'file: duckdns_timer']) }}

# Timer disabled by default — enable after creating /etc/duckdns.env
duckdns_not_enabled:
  service.disabled:
    - name: duckdns-update.timer
    - require:
      - file: duckdns_timer
{% endif %}
