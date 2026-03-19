# Loki + Promtail + Grafana monitoring stack (split from monitoring.sls)
{% from '_imports.jinja' import host %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% from '_macros_service.jinja' import service_with_unit, system_daemon_user, service_with_healthcheck, ensure_running, ensure_dir, unit_override %}
{% from '_macros_pkg.jinja' import simple_service, pacman_install %}
{% set mon = host.features.monitoring %}

# --- Loki: log aggregation ---
{{ pacman_install('loki', 'loki') }}
{{ system_daemon_user('loki', '/var/lib/loki') }}

# One-time cleanup: remove old manually-installed binary
loki_legacy_cleanup:
  file.absent:
    - name: /usr/local/bin/loki-linux-amd64
    - onlyif: test -f /usr/local/bin/loki-linux-amd64

loki_subdirs:
  file.directory:
    - names:
      - /var/lib/loki/chunks
      - /var/lib/loki/rules
      - /var/lib/loki/rules-temp
    - user: loki
    - group: loki
    - makedirs: True
    - require:
      - file: loki_data_dir

loki_config:
  file.managed:
    - name: /etc/loki/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/loki.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ catalog.loki.port }}

{{ service_with_unit('loki', 'salt://units/loki.service', running=True, watch=['file: loki_config'], requires=['cmd: install_loki', 'file: loki_config', 'file: loki_subdirs']) }}

# Defer Loki startup until after graphical.target to reduce boot I/O contention.
# Promtail reads journal retroactively — no early boot logs are lost.
{{ unit_override('loki_boot_defer', 'loki.service', 'salt://units/loki-boot-defer.conf', filename='boot-defer.conf', requires=['cmd: install_loki']) }}

{{ service_with_healthcheck('loki_start', 'loki', catalog=catalog, requires=['service: loki_enabled']) }}

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

{{ service_with_unit('promtail', 'salt://units/promtail.service', running=True, watch=['file: promtail_config'], requires=['cmd: install_promtail', 'file: promtail_config']) }}

{% set promtail_requires = ['service: promtail_enabled'] + (['cmd: loki_start'] if mon.loki else []) %}
{{ service_with_healthcheck('promtail_start', 'promtail', catalog=catalog, requires=promtail_requires) }}
{% endif %}

# --- Grafana: dashboard with Loki datasource ---
{% if mon.grafana %}
{% set grafana_requires = ['file: grafana_config'] + (['file: grafana_loki_datasource'] if mon.loki else []) %}
{{ simple_service('grafana', 'grafana', service='grafana', requires=grafana_requires) }}

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

{% set grafana_watch = ['file: grafana_config', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard'] + (['file: grafana_loki_datasource'] if mon.loki else []) %}
{{ ensure_running('grafana', service='grafana', watch=grafana_watch) }}

{{ service_with_healthcheck('grafana_start', 'grafana', catalog=catalog, requires=['service: grafana_enabled']) }}
{% endif %}
