{% from '_imports.jinja' import host, service_ports %}
{% from '_macros_service.jinja' import unit_override, service_with_unit, system_daemon_user, service_with_healthcheck, ensure_running, ensure_dir %}
{% from '_macros_github.jinja' import github_release_system %}
{% from '_macros_pkg.jinja' import simple_service %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set mon = host.features.monitoring %}

# --- Simple service enables ---
{% if mon.sysstat %}
{{ simple_service('sysstat', 'sysstat') }}
{% endif %}

{% if mon.vnstat %}
{{ simple_service('vnstat', 'vnstat') }}
{% endif %}

# --- Netdata: systemd override for conservative resource limits ---
{% if mon.netdata %}
{{ unit_override('netdata_override', 'netdata.service', 'salt://units/netdata-override.conf') }}
{% endif %}

# --- Loki: log aggregation ---
{% if mon.loki %}
{{ github_release_system('loki', 'grafana/loki', 'loki-linux-amd64.zip', src_bin='loki-linux-amd64', tag='v' ~ ver.get('loki', ''), hash='e9737023c71bc4381f7ced90a197a17a5908c1cf1b136bd381165e07ed50b1ac', version=ver.get('loki', '')) }}
{{ system_daemon_user('loki', '/var/lib/loki') }}

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
        loki_port: {{ service_ports.loki.port }}

{{ service_with_unit('loki', 'salt://units/loki.service', running=True, watch=['file: loki_config'], requires=['cmd: install_loki', 'file: loki_config', 'file: loki_subdirs']) }}

{{ service_with_healthcheck('loki_start', 'loki', 'curl -sf http://127.0.0.1:' ~ service_ports.loki.port ~ service_ports.loki.healthcheck ~ ' >/dev/null 2>&1', requires=['service: loki_enabled']) }}
{% endif %}

# --- Promtail: log shipper to Loki ---
{% if mon.promtail %}
{{ github_release_system('promtail', 'grafana/loki', 'promtail-linux-amd64.zip', src_bin='promtail-linux-amd64', tag='v' ~ ver.get('promtail', ''), hash='330f97bf7ef7e97cc2e42649ce7299129ab09dbffe5a2f5c515188502220987c', version=ver.get('promtail', '')) }}
{{ ensure_dir('promtail_cache_dir', '/var/cache/promtail', user='root') }}

promtail_config:
  file.managed:
    - name: /etc/promtail/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/promtail.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ service_ports.loki.port }}
        promtail_port: {{ service_ports.promtail.port }}

{{ service_with_unit('promtail', 'salt://units/promtail.service', running=True, watch=['file: promtail_config'], requires=['cmd: install_promtail', 'file: promtail_config']) }}

{% set promtail_requires = ['service: promtail_enabled'] + (['cmd: loki_start'] if mon.loki else []) %}
{{ service_with_healthcheck('promtail_start', 'promtail', 'curl -sf http://127.0.0.1:' ~ service_ports.promtail.port ~ service_ports.promtail.healthcheck ~ ' >/dev/null 2>&1', requires=promtail_requires) }}
{% endif %}

# --- Grafana: dashboard with Loki datasource ---
{% if mon.grafana %}
{{ simple_service('grafana', 'grafana', service='grafana', requires=['file: grafana_config', 'file: grafana_loki_datasource']) }}

grafana_loki_datasource:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/loki.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-loki-datasource.yaml.j2
    - template: jinja
    - context:
        loki_port: {{ service_ports.loki.port }}

grafana_config:
  file.managed:
    - name: /etc/grafana.ini
    - mode: '0640'
    - source: salt://configs/grafana.ini.j2
    - template: jinja
    - context:
        hostname: {{ host.hostname }}
        grafana_port: {{ service_ports.grafana.port }}

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

{{ ensure_running('grafana', service='grafana', watch=['file: grafana_config', 'file: grafana_loki_datasource', 'file: grafana_dashboards_provider', 'file: grafana_proxypilot_dashboard']) }}

{{ service_with_healthcheck('grafana_start', 'grafana', 'curl -sf http://127.0.0.1:' ~ service_ports.grafana.port ~ service_ports.grafana.healthcheck ~ ' >/dev/null 2>&1', requires=['service: grafana_enabled']) }}
{% endif %}
