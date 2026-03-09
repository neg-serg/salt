# Bitcoind: Bitcoin Core node (split from services.sls)
{% from '_imports.jinja' import host %}
{% from '_macros_service.jinja' import system_daemon_user, service_with_unit %}
{% from '_macros_install.jinja' import curl_extract_tar %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set svc = host.features.services %}

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
