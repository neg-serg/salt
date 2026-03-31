{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set cache = host.mnt_one ~ '/pkg/cache/amnezia' %}
# Salt state for Amnezia build and deploy (Local User version)
# All 3 components build in parallel for faster deployment
{{ ensure_dir('amnezia_cache_dir', cache, require=['mount: mount_one']) }}

# Build all Amnezia components in parallel
{% set _amnezia_ver = ver.get('amnezia_vpn', '') %}
{% set _amnezia_ver_marker = '/var/cache/salt/versions/amnezia_vpn@' ~ _amnezia_ver if _amnezia_ver else '' %}
amnezia_build:
  cmd.script:
    - source: salt://scripts/amnezia-build.sh
    - shell: /bin/bash
    - timeout: 3600
    - output_loglevel: info
    - env:
      - BUILD: {{ cache }}
      - AMNEZIA_VERSION: {{ _amnezia_ver }}
    - unless: >-
{%- if _amnezia_ver %}
        test -f {{ _amnezia_ver_marker }} &&
{%- endif %}
        test -f {{ cache }}/amneziawg-go-bin &&
        test -f {{ cache }}/awg-bin &&
        test -f {{ cache }}/AmneziaVPN-bin &&
        test -f {{ cache }}/AmneziaVPN-service-bin
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - file: amnezia_cache_dir

{% if _amnezia_ver %}
amnezia_version_stamp:
  cmd.run:
    - name: mkdir -p /var/cache/salt/versions && rm -f /var/cache/salt/versions/amnezia_vpn@* && touch {{ _amnezia_ver_marker }}
    - onchanges:
      - cmd: amnezia_build
{% endif %}

{% for state_id, src, dest in [
  ('amneziawg_go_bin', 'amneziawg-go-bin', 'amneziawg-go'),
  ('amneziawg_tools_bin', 'awg-bin', 'awg'),
  ('amnezia_vpn_bin', 'AmneziaVPN-bin', 'AmneziaVPN'),
  ('amnezia_service_bin', 'AmneziaVPN-service-bin', 'AmneziaVPN-service'),
] %}
{{ state_id }}:
  file.managed:
    - name: /usr/local/bin/{{ dest }}
    - source: {{ cache }}/{{ src }}
    - mode: '0755'
    - user: root
    - group: root
    - require:
      - cmd: amnezia_build
{% endfor %}

# Verification (only runs when the binary actually changed)
{% for state_id, cmd, bin_state in [
  ('amneziawg_go', '/usr/local/bin/amneziawg-go --version', 'amneziawg_go_bin'),
  ('awg', '/usr/local/bin/awg --version', 'amneziawg_tools_bin'),
  ('amnezia_vpn', 'ldd /usr/local/bin/AmneziaVPN', 'amnezia_vpn_bin'),
  ('amnezia_service', 'ldd /usr/local/bin/AmneziaVPN-service', 'amnezia_service_bin'),
] %}
{{ state_id }}_verify:
  cmd.run:
    - name: {{ cmd }}
    - onchanges:
      - file: {{ bin_state }}
{% endfor %}

# Systemd service for AmneziaVPN (runs as root for VPN tunnel management)
amnezia_systemd_unit:
  file.managed:
    - name: /usr/lib/systemd/system/AmneziaVPN-source.service
    - contents: |
        [Unit]
        Description=AmneziaVPN Service (source build)
        After=network.target
        StartLimitIntervalSec=0

        [Service]
        Type=simple
        Restart=always
        RestartSec=1
        ExecStart=/usr/local/bin/AmneziaVPN-service

        [Install]
        WantedBy=multi-user.target
    - require:
      - file: amnezia_service_bin

amnezia_service_enabled:
  service.enabled:
    - name: AmneziaVPN-source
    - require:
      - file: amnezia_systemd_unit

{{ ensure_dir('amnezia_apps_dir', home ~ '/.local/share/applications') }}

amnezia_desktop_entry:
  file.managed:
    - name: {{ home }}/.local/share/applications/amnezia-vpn.desktop
    - contents: |
        [Desktop Entry]
        Type=Application
        Name=AmneziaVPN (Source)
        Comment=Amnezia VPN Client (Self-built)
        Exec=/usr/local/bin/AmneziaVPN
        Icon=amnezia-vpn
        Terminal=false
        Categories=Network;VPN;
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: amnezia_apps_dir
