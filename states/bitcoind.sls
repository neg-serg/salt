{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service %}

# Bitcoin Core daemon — pure Quadlet (Podman container).
# Replaces native pacman package (bitcoin-daemon) + custom systemd unit.
# Service is manual_start — Salt deploys but does not auto-start.

{# In-place cutover: remove native systemd unit if it exists #}
bitcoind_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/bitcoind.service

bitcoind_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: bitcoind_native_unit_absent

{# Data directory for blockchain state #}
{{ ensure_dir('bitcoind_data_dir', '/var/lib/bitcoind-container', mode='0755', user='root') }}

{{ container_service('bitcoind', catalog.bitcoind, image_registry,
    requires=['file: bitcoind_data_dir', 'cmd: bitcoind_native_unit_daemon_reload']) }}
