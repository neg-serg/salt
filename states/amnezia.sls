{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}
{% set cache = '/mnt/one/pkg/cache/amnezia' %}
# Salt state for Amnezia build and deploy (Local User version)
# All 3 components build in parallel for faster deployment
{% if host.features.amnezia %}

{{ home }}/.local/bin:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{{ cache }}:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

# Build all Amnezia components in parallel
build_amnezia_all:
  cmd.script:
    - source: salt://scripts/amnezia-build.sh
    - shell: /bin/bash
    - timeout: 3600
    - output_loglevel: info
    - unless: >-
        test -f {{ cache }}/amneziawg-go-bin &&
        test -f {{ cache }}/awg-bin &&
        test -f {{ cache }}/AmneziaVPN-bin
    - require:
      - file: {{ cache }}

install_amneziawg_go:
  file.managed:
    - name: {{ home }}/.local/bin/amneziawg-go
    - source: {{ cache }}/amneziawg-go-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: build_amnezia_all

install_amneziawg_tools:
  file.managed:
    - name: {{ home }}/.local/bin/awg
    - source: {{ cache }}/awg-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: build_amnezia_all

# Symlinks for sudo access
/usr/local/bin/amneziawg-go:
  file.symlink:
    - target: {{ home }}/.local/bin/amneziawg-go
    - force: True
    - require:
      - file: install_amneziawg_go

/usr/local/bin/awg:
  file.symlink:
    - target: {{ home }}/.local/bin/awg
    - force: True
    - require:
      - file: install_amneziawg_tools

install_amnezia_vpn:
  file.managed:
    - name: {{ home }}/.local/bin/AmneziaVPN
    - source: {{ cache }}/AmneziaVPN-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: build_amnezia_all

# Verification (only runs when the binary actually changed)
verify_amneziawg_go:
  cmd.run:
    - name: {{ home }}/.local/bin/amneziawg-go --version
    - onchanges:
      - file: install_amneziawg_go

verify_awg:
  cmd.run:
    - name: {{ home }}/.local/bin/awg --version
    - onchanges:
      - file: install_amneziawg_tools

verify_amnezia_vpn:
  cmd.run:
    - name: ldd {{ home }}/.local/bin/AmneziaVPN
    - onchanges:
      - file: install_amnezia_vpn

{{ home }}/.local/share/applications:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

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
      - file: {{ home }}/.local/share/applications
{% endif %}
