{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload, ostree_install %}
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
install_loki:
  cmd.run:
    - name: |
        TAG=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | jq -r .tag_name)
        curl -sL "https://github.com/grafana/loki/releases/download/${TAG}/loki-linux-amd64.zip" -o /tmp/loki.zip
        unzip -o /tmp/loki.zip -d /tmp
        install -m 0755 /tmp/loki-linux-amd64 /usr/local/bin/loki
        rm -f /tmp/loki.zip /tmp/loki-linux-amd64
    - creates: /usr/local/bin/loki

loki_user:
  user.present:
    - name: loki
    - system: True
    - shell: /usr/sbin/nologin
    - home: /var/lib/loki
    - createhome: False

loki_data_dirs:
  file.directory:
    - names:
      - /var/lib/loki
      - /var/lib/loki/chunks
      - /var/lib/loki/rules
      - /var/lib/loki/rules-temp
    - user: loki
    - group: loki
    - makedirs: True
    - require:
      - user: loki_user

loki_config:
  file.managed:
    - name: /etc/loki/config.yaml
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/loki.yaml

loki_service:
  file.managed:
    - name: /etc/systemd/system/loki.service
    - mode: '0644'
    - source: salt://units/loki.service

{{ daemon_reload('loki', ['file: loki_service']) }}

loki_enabled:
  service.enabled:
    - name: loki
    - require:
      - file: loki_service
      - cmd: install_loki
      - file: loki_config
      - file: loki_data_dirs
{% endif %}

# --- Promtail: log shipper to Loki ---
{% if mon.promtail %}
install_promtail:
  cmd.run:
    - name: |
        TAG=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | jq -r .tag_name)
        curl -sL "https://github.com/grafana/loki/releases/download/${TAG}/promtail-linux-amd64.zip" -o /tmp/promtail.zip
        unzip -o /tmp/promtail.zip -d /tmp
        install -m 0755 /tmp/promtail-linux-amd64 /usr/local/bin/promtail
        rm -f /tmp/promtail.zip /tmp/promtail-linux-amd64
    - creates: /usr/local/bin/promtail

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

promtail_service:
  file.managed:
    - name: /etc/systemd/system/promtail.service
    - mode: '0644'
    - source: salt://units/promtail.service

{{ daemon_reload('promtail', ['file: promtail_service']) }}

promtail_enabled:
  service.enabled:
    - name: promtail
    - require:
      - file: promtail_service
      - cmd: install_promtail
      - file: promtail_config
{% endif %}

# --- Grafana: dashboard with Loki datasource ---
{% if mon.grafana %}
grafana_repo:
  file.managed:
    - name: /etc/yum.repos.d/grafana.repo
    - contents: |
        [grafana]
        name=Grafana OSS
        baseurl=https://rpm.grafana.com
        repo_gpgcheck=1
        enabled=1
        gpgcheck=1
        gpgkey=https://rpm.grafana.com/gpg.key
        sslverify=1
        sslcacert=/etc/pki/tls/certs/ca-bundle.crt
    - mode: '0644'

{{ ostree_install('grafana', 'grafana', requires=['file: grafana_repo']) }}

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
