{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import unit_override, service_with_unit, system_daemon_user, service_with_healthcheck %}
{% from '_macros_github.jinja' import github_release_system %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set mon = host.features.monitoring %}

# --- Simple service enables (packages already in system_description.sls) ---
{% if mon.sysstat %}
sysstat_enabled:
  service.enabled:
    - name: sysstat
{% endif %}

{% if mon.vnstat %}
vnstat_enabled:
  service.enabled:
    - name: vnstat
{% endif %}

# --- Netdata: systemd override for conservative resource limits ---
{% if mon.netdata %}
{{ unit_override('netdata_override', 'netdata.service', 'salt://units/netdata-override.conf') }}
{% endif %}

# --- Loki: log aggregation ---
{% if mon.loki %}
{{ github_release_system('loki', 'grafana/loki', 'loki-linux-amd64.zip', src_bin='loki-linux-amd64', tag='v' ~ ver.loki) }}
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
    - source: salt://configs/loki.yaml

{{ service_with_unit('loki', 'salt://units/loki.service', running=True, watch=['file: loki_config'], requires=['cmd: install_loki', 'file: loki_config', 'file: loki_subdirs']) }}

{{ service_with_healthcheck('loki_start', 'loki', 'curl -sf http://127.0.0.1:3100/ready >/dev/null 2>&1', requires=['service: loki_enabled']) }}
{% endif %}

# --- Promtail: log shipper to Loki ---
{% if mon.promtail %}
{{ github_release_system('promtail', 'grafana/loki', 'promtail-linux-amd64.zip', src_bin='promtail-linux-amd64', tag='v' ~ ver.promtail) }}
promtail_cache_dir:
  file.directory:
    - name: /var/cache/promtail
    - user: root
    - group: root
    - makedirs: True

promtail_config:
  file.managed:
    - name: /etc/promtail/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/promtail.yaml.j2
    - template: jinja

{{ service_with_unit('promtail', 'salt://units/promtail.service', running=True, watch=['file: promtail_config'], requires=['cmd: install_promtail', 'file: promtail_config']) }}

{% set promtail_requires = ['service: promtail_enabled'] + (['cmd: loki_start'] if mon.loki else []) %}
{{ service_with_healthcheck('promtail_start', 'promtail', 'curl -sf http://127.0.0.1:9080/ready >/dev/null 2>&1', requires=promtail_requires) }}
{% endif %}

# --- Grafana: dashboard with Loki datasource ---
{% if mon.grafana %}
{{ pacman_install('grafana', 'grafana') }}

grafana_provisioning_dir:
  file.directory:
    - name: /etc/grafana/provisioning/datasources
    - makedirs: True

grafana_loki_datasource:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/loki.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/grafana-loki-datasource.yaml
    - require:
      - file: grafana_provisioning_dir

grafana_config:
  file.managed:
    - name: /etc/grafana/grafana.ini
    - mode: '0640'
    - source: salt://configs/grafana.ini.j2
    - template: jinja
    - context:
        hostname: {{ grains['host'] }}

grafana_enabled:
  service.enabled:
    - name: grafana-server
    - require:
      - file: grafana_config
      - file: grafana_loki_datasource

grafana_running:
  service.running:
    - name: grafana-server
    - watch:
      - file: grafana_config
      - file: grafana_loki_datasource
    - require:
      - service: grafana_enabled

{{ service_with_healthcheck('grafana_start', 'grafana-server', 'curl -sf http://127.0.0.1:3030/api/health >/dev/null 2>&1', requires=['service: grafana_enabled']) }}
{% endif %}
