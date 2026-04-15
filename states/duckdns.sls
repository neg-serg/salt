{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service %}

# DuckDNS dynamic DNS updater — pure Quadlet (Podman container).
# Replaces native zsh script + systemd timer/service pair.
#
# The linuxserver/duckdns image reads SUBDOMAINS and TOKEN from environment.
# We use EnvironmentFile=/etc/duckdns.env which provides DUCKDNS_TOKEN and
# DUCKDNS_DOMAIN — the container entrypoint script maps these.

{# In-place cutover: remove native timer + service + script #}
duckdns_native_timer_absent:
  file.absent:
    - name: /etc/systemd/system/duckdns-update.timer

duckdns_native_service_absent:
  file.absent:
    - name: /etc/systemd/system/duckdns-update.service

duckdns_native_script_absent:
  file.absent:
    - name: /usr/local/bin/duckdns-update

duckdns_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: duckdns_native_timer_absent
      - file: duckdns_native_service_absent

{# Ensure env file exists before container starts (may be empty initially) #}
{{ ensure_dir('duckdns_env_dir', '/etc', mode='0755', user='root') }}

{{ container_service('duckdns', catalog.duckdns, image_registry,
    requires=['cmd: duckdns_native_unit_daemon_reload']) }}
