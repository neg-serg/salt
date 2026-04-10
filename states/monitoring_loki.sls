# Loki + Promtail + Grafana monitoring stack (split from monitoring.sls)
#
# Feature 087-containerize-services (US2, blue/green cutover):
#   features.containers.loki/promtail/grafana flip each service between its
#   native deployment (default) and a containerized Podman Quadlet form.
#
# Loki uses TRUE blue/green: when containerized, the native Loki stays
# running on a secondary port (3101) for historical queries during the
# rollback window, and the containerized Loki takes over the primary port
# (3100). Promtail and Grafana use hard cutover: when containerized, the
# native service is stopped (but pacman package stays installed until T054).
#
# To avoid systemd unit-name collisions between native (/usr/lib/systemd/)
# and Quadlet-generated (/run/systemd/) units when both coexist during the
# window, the containerized forms use distinct unit basenames:
#   - Native loki.service     ↔ containerized loki-container.service
#   - Native promtail.service ↔ containerized promtail-container.service
#   - Native grafana.service  ↔ containerized grafana-container.service
# Passed to container_service() via the quadlet_unit_name= parameter.
{% from '_imports.jinja' import host %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, ensure_running, service_stopped, service_with_healthcheck, service_with_unit_and_healthcheck, unit_override, container_service %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% set mon = host.features.monitoring %}
{% set _loki_containerized = host.features.get('containers', {}).get('loki', False) %}
{% set _promtail_containerized = host.features.get('containers', {}).get('promtail', False) %}
{% set _grafana_containerized = host.features.get('containers', {}).get('grafana', False) %}
{# Native Loki port: 3101 during the rollback window (historical archive),
   3100 otherwise (primary). Containerized Loki always binds the primary. #}
{% set _loki_native_port = 3101 if _loki_containerized else catalog.loki.port %}

# --- Loki: log aggregation ---
{{ pacman_install('loki', 'loki') }}

# One-time cleanup: remove old manually-installed binary
loki_legacy_cleanup:
  file.absent:
    - name: /usr/local/bin/loki-linux-amd64
    - onlyif: test -f /usr/local/bin/loki-linux-amd64

loki_config:
  file.managed:
    - name: /etc/loki/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/loki.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ _loki_native_port }}

{% if _loki_containerized %}
# Blue/green: native Loki keeps running on 3101 for historical queries.
# Use an explicit check_cmd because the catalog lookup would probe the
# primary port 3100 (now owned by the container).
{% set _loki_native_check = 'curl -sf http://127.0.0.1:3101/ready >/dev/null 2>&1' %}
{{ service_with_unit_and_healthcheck('loki', 'salt://units/loki.service', running=True, watch=['file: loki_config'], requires=['cmd: install_loki', 'file: loki_config', 'cmd: managed_service_accounts_ensure', 'cmd: managed_service_paths_ensure'], check_cmd=_loki_native_check) }}
{% else %}
{{ service_with_unit_and_healthcheck('loki', 'salt://units/loki.service', running=True, watch=['file: loki_config'], requires=['cmd: install_loki', 'file: loki_config', 'cmd: managed_service_accounts_ensure', 'cmd: managed_service_paths_ensure'], catalog=catalog) }}
{% endif %}

# Defer Loki startup until after graphical.target to reduce boot I/O contention.
# Promtail reads journal retroactively — no early boot logs are lost.
{{ unit_override('loki_boot_defer', 'loki.service', 'salt://units/loki-boot-defer.conf', filename='boot-defer.conf', requires=['cmd: install_loki']) }}

{% if _loki_containerized %}
# ── Containerized Loki (primary, port 3100) ──
{{ ensure_dir('loki_container_state_dir', '/var/lib/loki-container', user='root') }}
{{ container_service('loki', catalog.loki, image_registry,
    quadlet_unit_name='loki-container',
    requires=['file: loki_config', 'cmd: managed_service_paths_ensure', 'file: loki_container_state_dir']) }}
{% else %}
# When not containerized, make sure any leftover Quadlet unit file is removed
# so systemd doesn't carry a ghost unit alongside the native service.
loki_quadlet_absent:
  file.absent:
    - name: /etc/containers/systemd/loki-container.container
{% endif %}

# --- Promtail: log shipper to Loki ---
# Note: promtail pushes to Loki — enabling promtail without loki results in
# a running service that fails to connect. Gate on both flags for safety.
{% if mon.promtail and mon.loki %}
{{ pacman_install('promtail', 'promtail') }}
{{ ensure_dir('promtail_cache_dir', '/var/cache/promtail', user='root') }}

# One-time cleanup: remove old manually-installed binary
promtail_legacy_cleanup:
  file.absent:
    - name: /usr/local/bin/promtail-linux-amd64
    - onlyif: test -f /usr/local/bin/promtail-linux-amd64

promtail_config:
  file.managed:
    - name: /etc/promtail/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/promtail.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ catalog.loki.port }}
        promtail_port: {{ catalog.promtail.port }}

{% if _promtail_containerized %}
# Hard cutover: native Promtail is stopped (only one journal shipper should
# run at a time). Native package stays installed until T054.
{{ service_stopped('promtail_native_dead', 'promtail', requires=['cmd: install_promtail']) }}

# ── Containerized Promtail ──
{{ container_service('promtail', catalog.promtail, image_registry,
    quadlet_unit_name='promtail-container',
    requires=['cmd: install_promtail', 'file: promtail_config', 'cmd: managed_service_paths_ensure']) }}
{% else %}
{% set promtail_hc_requires = ['service: promtail_enabled'] + (['cmd: loki_start'] if mon.loki else []) %}
{{ service_with_unit_and_healthcheck('promtail', 'salt://units/promtail.service', running=True, watch=['file: promtail_config'], requires=['cmd: install_promtail', 'file: promtail_config'], catalog=catalog, healthcheck_requires=promtail_hc_requires) }}

promtail_quadlet_absent:
  file.absent:
    - name: /etc/containers/systemd/promtail-container.container
{% endif %}
{% endif %}

# --- Grafana: dashboard with Loki datasource ---
{% if mon.grafana %}
# Native grafana package stays installed unconditionally so /etc/grafana/
# directory structure exists for the provisioning file.managed states below
# (which are the bind-mount source for the containerized Grafana — FR-018
# provisioning-as-code).
{{ pacman_install('grafana', 'grafana') }}

{% if mon.loki %}
grafana_loki_datasource:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/loki.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-loki-datasource.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ catalog.loki.port }}
{% endif %}

grafana_config:
  file.managed:
    - name: /etc/grafana.ini
    - mode: '0640'
    - source: salt://configs/grafana.ini.j2
    - template: jinja
    - context:
        hostname: {{ host.hostname }}
        grafana_port: {{ catalog.grafana.port }}

grafana_dashboards_provider:
  file.managed:
    - name: /etc/grafana/provisioning/dashboards/dashboards.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-dashboards-provider.yaml

grafana_proxypilot_dashboard:
  file.managed:
    - name: /etc/grafana/provisioning/dashboards/json/proxypilot.json
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-dashboard-proxypilot.json

{% if _grafana_containerized %}
# Hard cutover: native grafana service is stopped. Provisioning files above
# stay deployed — they're the bind-mount source for the container.
{{ service_stopped('grafana_native_dead', 'grafana', requires=['cmd: install_grafana']) }}

# Temporary native-archive datasource for Grafana Explore (T037 sub-step 6,
# FR-018). Deployed ONLY while Loki is containerized so historical queries
# against the native Loki on port 3101 remain accessible during the
# rollback window. T054 removes this file atomically with the native
# loki package when the window closes — leaving it behind is a spec
# violation.
{% if _loki_containerized %}
grafana_loki_native_archive_datasource:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/loki-native-archive.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-loki-native-archive.yaml.j2
    - template: jinja
    - context:
        native_archive_port: 3101
        cutover_expiry: "cutover_date + 7 days"
    - require:
      - cmd: install_grafana
{% else %}
grafana_loki_native_archive_absent:
  file.absent:
    - name: /etc/grafana/provisioning/datasources/loki-native-archive.yaml
{% endif %}

# ── Containerized Grafana ──
{{ ensure_dir('grafana_container_state_dir', '/var/lib/grafana-container', user='root') }}
{% set _grafana_watch = ['file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard'] + (['file: grafana_loki_datasource'] if mon.loki else []) %}
{{ container_service('grafana', catalog.grafana, image_registry,
    quadlet_unit_name='grafana-container',
    requires=['cmd: install_grafana', 'file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard', 'file: grafana_container_state_dir'],
    watch=_grafana_watch) }}
{% else %}
grafana_enabled:
  service.enabled:
    - name: grafana
    - require:
      - cmd: install_grafana
      - file: grafana_config
{% if mon.loki %}
      - file: grafana_loki_datasource
{% endif %}

{% set grafana_watch = ['file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard'] + (['file: grafana_loki_datasource'] if mon.loki else []) %}
{{ ensure_running('grafana', service='grafana', watch=grafana_watch) }}

{{ service_with_healthcheck('grafana_start', 'grafana', catalog=catalog, requires=['service: grafana_enabled']) }}

grafana_quadlet_absent:
  file.absent:
    - name: /etc/containers/systemd/grafana-container.container

grafana_loki_native_archive_absent:
  file.absent:
    - name: /etc/grafana/provisioning/datasources/loki-native-archive.yaml
{% endif %}
{% endif %}
