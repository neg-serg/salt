{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service %}

# Transmission BitTorrent client — pure Quadlet (Podman container).
# Replaces native pacman package (transmission-cli) + escape hatch logic.
#
# ACLs and config replacement are no longer needed:
# - ACLs were for granting 'transmission' user access to ~/dw and ~/torrent/data
#   → replaced by bind mounts (container runs as USER_UID/USER_GID)
# - config replacement (sed on settings.json) was for download-dir/watch-dir
#   → replaced by bind mount paths + linuxserver env vars

{# In-place cutover: remove native systemd unit if it exists so the
   Quadlet-generated unit at /run/systemd/system/transmission.service is
   no longer shadowed by /etc/systemd/system/transmission.service. #}
transmission_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/transmission.service

transmission_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: transmission_native_unit_absent

{# Directories that will be bind-mounted into the container #}
{{ ensure_dir('transmission_config_dir', '/etc/transmission', mode='0755') }}
{{ ensure_dir('transmission_watch_dir', home ~ '/dw', mode='0755') }}
{{ ensure_dir('transmission_download_dir', home ~ '/torrent/data', mode='0755') }}

{{ container_service('transmission', catalog.transmission, image_registry,
    requires=['file: transmission_config_dir', 'file: transmission_watch_dir', 'file: transmission_download_dir', 'cmd: transmission_native_unit_daemon_reload']) }}
