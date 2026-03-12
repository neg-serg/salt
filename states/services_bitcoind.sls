# Bitcoind: Bitcoin Core node (split from services.sls)
{% from '_imports.jinja' import host %}
{% from '_macros_service.jinja' import system_daemon_user, service_with_unit %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% set svc = host.features.services %}

{% if svc.bitcoind %}
{{ pacman_install('bitcoind', 'bitcoin-daemon') }}

# One-time cleanup: remove old manually-installed binaries
bitcoind_legacy_cleanup:
  file.absent:
    - names:
      - /usr/local/bin/bitcoind
      - /usr/local/bin/bitcoin-cli
    - onlyif: test -f /usr/local/bin/bitcoind

{{ system_daemon_user('bitcoind', '/var/lib/bitcoind') }}

# Don't enable at boot — manual start: systemctl start bitcoind
{{ service_with_unit('bitcoind', 'salt://units/bitcoind.service', enabled=False) }}

bitcoind_logrotate:
  file.managed:
    - name: /etc/logrotate.d/bitcoind
    - mode: '0644'
    - source: salt://configs/bitcoind-logrotate
{% endif %}
