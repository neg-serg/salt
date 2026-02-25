{% from '_imports.jinja' import host, user %}
{% from '_macros_service.jinja' import ensure_dir, system_daemon_user, service_with_unit, service_stopped %}
{% from '_macros_install.jinja' import curl_extract_tar %}
{% from '_macros_pkg.jinja' import pacman_install, simple_service %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/services.yaml' as services %}
{% set svc = host.features.services %}

# ===================================================================
# Simple services (data-driven: pacman install + service enable)
# ===================================================================

{% for name, opts in services.simple.items() %}
{% if svc.get(name, False) %}
{{ simple_service(name, opts.packages, service=opts.service) }}
{% endif %}
{% endfor %}

# ===================================================================
# Complex services (custom logic, not data-driven)
# ===================================================================

# --- Samba: SMB file sharing (manual start) ---
{% if svc.samba %}
{{ pacman_install('samba', 'samba') }}

{{ ensure_dir('samba_share_dir', host.mnt_zero ~ '/sync/smb', mode='0755', require=['mount: mount_zero']) }}

samba_config:
  file.managed:
    - name: /etc/samba/smb.conf
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/smb.conf.j2
    - template: jinja
    - context:
        hostname: {{ host.hostname }}
        mnt_zero: {{ host.mnt_zero }}
        user: {{ user }}

# Don't enable at boot — manual start only: systemctl start smb
{{ service_stopped('samba_not_enabled', 'smb', stop=False, requires=['file: samba_config']) }}
{% endif %}

# --- Bitcoind: Bitcoin Core node ---
{% if svc.bitcoind %}
{% set _btc_ver = ver.get('bitcoind', '') %}
{% set btc_url = 'https://bitcoincore.org/bin/bitcoin-core-${VER}/bitcoin-${VER}-x86_64-linux-gnu.tar.gz' | replace('${VER}', _btc_ver) %}
{% set btc_pattern = 'bitcoin-${VER}/bin' | replace('${VER}', _btc_ver) %}
{{ curl_extract_tar('bitcoind', btc_url, binary_pattern=btc_pattern, binaries=['bitcoind', 'bitcoin-cli'], bin_dest='/usr/local/bin', hash='07f77afd326639145b9ba9562912b2ad2ccec47b8a305bd075b4f4cb127b7ed7', version=_btc_ver if _btc_ver else None, user=None) }}

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

# Timer disabled by default — enable after creating /etc/duckdns.env
{{ service_with_unit('duckdns-update', 'salt://units/duckdns-update.timer', unit_type='timer', enabled=False, companion='salt://units/duckdns-update.service') }}
{% endif %}
