{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}
# Salt state for Amnezia build and deploy (Local User version)
# All 3 components build in parallel for faster deployment

{{ home }}/.local/bin:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

/mnt/one/pkg/cache/amnezia:
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
        test -f /mnt/one/pkg/cache/amnezia/amneziawg-go-bin &&
        test -f /mnt/one/pkg/cache/amnezia/awg-bin &&
        test -f /mnt/one/pkg/cache/amnezia/AmneziaVPN-bin
    - require:
      - file: /mnt/one/pkg/cache/amnezia

install_amneziawg_go:
  file.managed:
    - name: {{ home }}/.local/bin/amneziawg-go
    - source: /mnt/one/pkg/cache/amnezia/amneziawg-go-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: build_amnezia_all

install_amneziawg_tools:
  file.managed:
    - name: {{ home }}/.local/bin/awg
    - source: /mnt/one/pkg/cache/amnezia/awg-bin
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
    - source: /mnt/one/pkg/cache/amnezia/AmneziaVPN-bin
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: build_amnezia_all

# Verification
verify_amneziawg_go:
  cmd.run:
    - name: {{ home }}/.local/bin/amneziawg-go --version
    - require:
      - file: install_amneziawg_go

verify_awg:
  cmd.run:
    - name: {{ home }}/.local/bin/awg --version
    - require:
      - file: install_amneziawg_tools

verify_amnezia_vpn:
  cmd.run:
    - name: ldd {{ home }}/.local/bin/AmneziaVPN
    - require:
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
