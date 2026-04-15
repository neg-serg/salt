{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service, service_with_healthcheck %}

# AdGuard Home DNS filter — pure Quadlet (Podman container).
# Replaces native pacman package (adguardhome) + custom systemd unit.
#
# Host-level integration that stays outside the container:
# - /etc/systemd/resolved.conf.d/adguardhome.conf (systemd-resolved redirect)

{# ── Cleanup legacy binary ── #}
adguardhome_legacy_cleanup:
  file.absent:
    - name: /usr/local/bin/AdGuardHome
    - onlyif: test -f /usr/local/bin/AdGuardHome

{# ── In-place cutover: remove native systemd unit ── #}
adguardhome_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/adguardhome.service

adguardhome_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: adguardhome_native_unit_absent

{# ── Work directory for container bind-mount ── #}
{{ ensure_dir('adguardhome_work_dir', '/var/lib/adguardhome-container', mode='0755', user='root') }}

{# ── Initial config seed (replace: False — AdGuardHome rewrites it) ── #}
adguardhome_initial_config:
  file.managed:
    - name: /var/lib/adguardhome-container/AdGuardHome.yaml
    - source: salt://configs/adguardhome-initial.yaml
    - user: root
    - group: root
    - mode: '0640'
    - replace: False
    - makedirs: True
    - require:
      - file: adguardhome_work_dir

{# ── systemd-resolved integration (host-level, stays outside container) ── #}
adguardhome_resolved_conf:
  file.managed:
    - name: /etc/systemd/resolved.conf.d/adguardhome.conf
    - source: salt://configs/resolved-adguardhome.conf
    - mode: '0644'
    - makedirs: True

systemd_resolved_restart_on_adguardhome_change:
  cmd.run:
    - name: systemctl restart systemd-resolved
    - onchanges:
      - file: adguardhome_resolved_conf

{# ── Container deployment ── #}
{{ container_service('adguardhome', catalog.adguardhome, image_registry,
    requires=['file: adguardhome_work_dir', 'file: adguardhome_initial_config', 'cmd: adguardhome_native_unit_daemon_reload']) }}

{# ── Healthcheck ── #}
{{ service_with_healthcheck('adguardhome_start', 'adguardhome',
    'curl -sf http://127.0.0.1:3000/ >/dev/null 2>&1',
    requires=['cmd: adguardhome_running']) }}
