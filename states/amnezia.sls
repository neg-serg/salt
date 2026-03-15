{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set cache = host.mnt_one ~ '/pkg/cache/amnezia' %}
# Salt state for Amnezia build and deploy (Local User version)
# All 3 components build in parallel for faster deployment
{{ ensure_dir('amnezia_bin_dir', home ~ '/.local/bin') }}

{{ ensure_dir('amnezia_cache_dir', cache, require=['mount: mount_one']) }}

# Build all Amnezia components in parallel
amnezia_build:
  cmd.script:
    - source: salt://scripts/amnezia-build.sh
    - shell: /bin/bash
    - timeout: 3600
    - output_loglevel: info
    - env:
      - BUILD: {{ cache }}
      - AMNEZIA_VERSION: {{ ver.get('amnezia_vpn', '') }}
    - unless: >-
        test -f {{ cache }}/amneziawg-go-bin &&
        test -f {{ cache }}/awg-bin &&
        test -f {{ cache }}/AmneziaVPN-bin
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - file: amnezia_cache_dir

amneziawg_go_bin:
  file.managed:
    - name: {{ home }}/.local/bin/amneziawg-go
    - source: {{ cache }}/amneziawg-go-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: amnezia_build

amneziawg_tools_bin:
  file.managed:
    - name: {{ home }}/.local/bin/awg
    - source: {{ cache }}/awg-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: amnezia_build

# Symlinks for sudo access (root owns /usr/local/bin/)
{% for bin_name, bin_state in [('amneziawg-go', 'amneziawg_go_bin'), ('awg', 'amneziawg_tools_bin')] %}
{{ bin_name | replace('-', '_') }}_symlink:
  file.symlink:
    - name: /usr/local/bin/{{ bin_name }}
    - target: {{ home }}/.local/bin/{{ bin_name }}
    - force: True
    - user: root
    - group: root
    - require:
      - file: {{ bin_state }}
{% endfor %}

amnezia_vpn_bin:
  file.managed:
    - name: {{ home }}/.local/bin/AmneziaVPN
    - source: {{ cache }}/AmneziaVPN-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: amnezia_build

# Verification (only runs when the binary actually changed)
{% for state_id, cmd, bin_state in [
  ('amneziawg_go', home ~ '/.local/bin/amneziawg-go --version', 'amneziawg_go_bin'),
  ('awg', home ~ '/.local/bin/awg --version', 'amneziawg_tools_bin'),
  ('amnezia_vpn', 'ldd ' ~ home ~ '/.local/bin/AmneziaVPN', 'amnezia_vpn_bin'),
] %}
{{ state_id }}_verify:
  cmd.run:
    - name: {{ cmd }}
    - onchanges:
      - file: {{ bin_state }}
{% endfor %}

{{ ensure_dir('amnezia_apps_dir', home ~ '/.local/share/applications') }}

amnezia_desktop_entry:
  file.managed:
    - name: {{ home }}/.local/share/applications/amnezia-vpn.desktop
    - contents: |
        [Desktop Entry]
        Type=Application
        Name=AmneziaVPN (Source)
        Comment=Amnezia VPN Client (Self-built)
        Exec={{ home }}/.local/bin/AmneziaVPN
        Icon=amnezia-vpn
        Terminal=false
        Categories=Network;VPN;
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: amnezia_apps_dir
