{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload, pacman_install, service_with_unit, system_daemon_user, github_release_system %}
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
netdata_override_dir:
  file.directory:
    - name: /etc/systemd/system/netdata.service.d
    - makedirs: True

netdata_override:
  file.managed:
    - name: /etc/systemd/system/netdata.service.d/override.conf
    - contents: |
        [Service]
        Nice=19
        IOSchedulingClass=idle
        IOSchedulingPriority=7
        CPUWeight=10
        IOWeight=10
        MemoryMax=256M
    - mode: '0644'
    - require:
      - file: netdata_override_dir

{{ daemon_reload('netdata', ['file: netdata_override']) }}
{% endif %}

# --- Loki: log aggregation ---
{% if mon.loki %}
{{ github_release_system('loki', 'grafana/loki', 'loki-linux-amd64.zip', src_bin='loki-linux-amd64') }}

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

{{ service_with_unit('loki', 'salt://units/loki.service', requires=['cmd: install_loki', 'file: loki_config', 'file: loki_subdirs']) }}
{% endif %}

# --- Promtail: log shipper to Loki ---
{% if mon.promtail %}
{{ github_release_system('promtail', 'grafana/loki', 'promtail-linux-amd64.zip', src_bin='promtail-linux-amd64') }}

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

{{ service_with_unit('promtail', 'salt://units/promtail.service', requires=['cmd: install_promtail', 'file: promtail_config']) }}
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
{% endif %}
