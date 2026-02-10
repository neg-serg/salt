{% from 'host_config.jinja' import host %}
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
    - name: vnstatd
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

netdata_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: netdata_override
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
    - contents: |
        auth_enabled: false
        server:
          http_listen_address: 127.0.0.1
          http_listen_port: 3100
          grpc_listen_port: 0
        common:
          path_prefix: /var/lib/loki
          storage:
            filesystem:
              chunks_directory: /var/lib/loki/chunks
              rules_directory: /var/lib/loki/rules
          replication_factor: 1
          ring:
            instance_addr: 127.0.0.1
            kvstore:
              store: inmemory
        schema_config:
          configs:
            - from: "2020-10-24"
              store: boltdb-shipper
              object_store: filesystem
              schema: v13
              index:
                prefix: index_
                period: 24h
        ruler:
          rule_path: /var/lib/loki/rules-temp
          storage:
            type: local
            local:
              directory: /var/lib/loki/rules
          alertmanager_url: http://127.0.0.1:9093
        analytics:
          reporting_enabled: false
        limits_config:
          allow_structured_metadata: false
          retention_period: 30d
        table_manager:
          retention_deletes_enabled: true
          retention_period: 30d

loki_service:
  file.managed:
    - name: /etc/systemd/system/loki.service
    - mode: '0644'
    - contents: |
        [Unit]
        Description=Grafana Loki log aggregation
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        User=loki
        Group=loki
        ExecStart=/usr/local/bin/loki -config.file=/etc/loki/config.yaml
        Restart=on-failure
        RestartSec=5

        [Install]
        WantedBy=multi-user.target

loki_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: loki_service

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
    - contents: |
        server:
          http_listen_port: 9080
          grpc_listen_port: 0
        positions:
          filename: /var/cache/promtail/positions.yaml
        clients:
          - url: http://127.0.0.1:3100/loki/api/v1/push
        scrape_configs:
          - job_name: journal
            journal:
              path: /var/log/journal
              max_age: 12h
              labels:
                job: systemd-journal
                host: {{ grains['host'] }}
            relabel_configs:
              - source_labels: ["__journal__systemd_unit"]
                target_label: unit
              - source_labels: ["__journal_priority"]
                target_label: priority
              - source_labels: ["__journal__hostname"]
                target_label: host
          - job_name: varlogs
            static_configs:
              - targets:
                  - localhost
                labels:
                  job: varlogs
                  __path__: /var/log/*.log

promtail_service:
  file.managed:
    - name: /etc/systemd/system/promtail.service
    - mode: '0644'
    - contents: |
        [Unit]
        Description=Promtail log shipper for Loki
        After=network-online.target loki.service
        Wants=network-online.target

        [Service]
        Type=simple
        ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yaml
        Restart=on-failure
        RestartSec=5

        [Install]
        WantedBy=multi-user.target

promtail_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: promtail_service

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

install_grafana:
  cmd.run:
    - name: rpm-ostree install --idempotent --apply-live grafana
    - unless: rpm -q grafana
    - require:
      - file: grafana_repo

grafana_provisioning_dir:
  file.directory:
    - name: /etc/grafana/provisioning/datasources
    - makedirs: True

grafana_loki_datasource:
  file.managed:
    - name: /etc/grafana/provisioning/datasources/loki.yaml
    - makedirs: True
    - mode: '0644'
    - contents: |
        apiVersion: 1
        datasources:
          - uid: loki
            name: Loki
            type: loki
            access: proxy
            url: http://127.0.0.1:3100
            isDefault: true
            jsonData: {}
    - require:
      - file: grafana_provisioning_dir

grafana_config:
  file.managed:
    - name: /etc/grafana/grafana.ini
    - mode: '0640'
    - contents: |
        [server]
        http_port = 3030
        http_addr = 0.0.0.0
        domain = {{ grains['host'] }}

        [security]
        admin_user = admin

        [paths]
        provisioning = /etc/grafana/provisioning

        [analytics]
        reporting_enabled = false
        check_for_updates = false

grafana_enabled:
  service.enabled:
    - name: grafana-server
    - require:
      - file: grafana_config
      - file: grafana_loki_datasource
{% endif %}
