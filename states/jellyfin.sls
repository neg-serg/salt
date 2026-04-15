{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service %}

# Jellyfin media server — pure Quadlet (Podman container).
# Replaces native pacman packages (jellyfin-server, jellyfin-web).

{# In-place cutover: remove native systemd unit if it exists so the
   Quadlet-generated unit at /run/systemd/system/jellyfin.service is
   no longer shadowed by /etc/systemd/system/jellyfin.service. #}
jellyfin_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/jellyfin.service

jellyfin_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: jellyfin_native_unit_absent

{# Config + cache directories on host — container bind-mounts need them to exist #}
{{ ensure_dir('jellyfin_config_dir', '/etc/jellyfin', mode='0755') }}
{{ ensure_dir('jellyfin_cache_dir', '/var/cache/jellyfin', mode='0755') }}

{{ container_service('jellyfin', catalog.jellyfin, image_registry,
    requires=['file: jellyfin_config_dir', 'file: jellyfin_cache_dir', 'cmd: jellyfin_native_unit_daemon_reload']) }}
