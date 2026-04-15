# Loki + Promtail + Grafana monitoring stack — pure Quadlet (Podman containers).
# All three services run exclusively as containers; native packages stay
# installed for /etc/ directory structure and provisioning files.
{% from '_imports.jinja' import host %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, service_stopped, container_service %}
{% from '_macros_pkg.jinja' import paru_install %}
{% set mon = host.features.monitoring %}

{# ── Loki: log aggregation ── #}
{{ paru_install('loki', 'loki') }}

loki_config:
  file.managed:
    - name: /etc/loki/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/loki.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ catalog.loki.port }}

{{ service_stopped('loki_native_dead', 'loki', requires=['cmd: install_loki']) }}

{{ ensure_dir('loki_container_state_dir', '/var/lib/loki-container', user='root') }}
{{ container_service('loki', catalog.loki, image_registry,
    quadlet_unit_name='loki-container',
    requires=['file: loki_config', 'file: loki_container_state_dir', 'cmd: managed_service_accounts_ensure', 'cmd: managed_service_paths_ensure']) }}

{# ── Promtail: log shipper to Loki ── #}
{% if mon.promtail and mon.loki %}
{{ paru_install('promtail', 'promtail') }}

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

{{ service_stopped('promtail_native_dead', 'promtail', requires=['cmd: install_promtail']) }}

{{ ensure_dir('promtail_cache_dir', '/var/cache/promtail', user='root') }}
{{ container_service('promtail', catalog.promtail, image_registry,
    quadlet_unit_name='promtail-container',
    requires=['cmd: install_promtail', 'file: promtail_config']) }}
{% endif %}

{# ── Grafana: dashboard with Loki datasource ── #}
{% if mon.grafana %}
{{ paru_install('grafana', 'grafana') }}

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

{{ service_stopped('grafana_native_dead', 'grafana', requires=['cmd: install_grafana']) }}

{{ ensure_dir('grafana_container_state_dir', '/var/lib/grafana-container', user='root') }}
{% set _grafana_watch = ['file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard'] + (['file: grafana_loki_datasource'] if mon.loki else []) %}
{{ container_service('grafana', catalog.grafana, image_registry,
    quadlet_unit_name='grafana-container',
    requires=['cmd: install_grafana', 'file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard', 'file: grafana_container_state_dir'],
    watch=_grafana_watch) }}
{% endif %}
