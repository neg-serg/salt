# Salt state for Amnezia build and deploy (Local User version)
# All 3 components build in parallel for faster deployment

/var/home/neg/.local/bin:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

# Build all Amnezia components in parallel
build_amnezia_all:
  cmd.script:
    - source: salt://scripts/amnezia-build.sh
    - shell: /bin/bash
    - timeout: 3600
    - output_loglevel: info
    - unless: >-
        test -f /var/mnt/one/pkg/cache/amnezia/amneziawg-go-bin &&
        test -f /var/mnt/one/pkg/cache/amnezia/awg-bin &&
        test -f /var/mnt/one/pkg/cache/amnezia/AmneziaVPN-bin
    - require:
      - file: /var/mnt/one/pkg/cache/amnezia

install_amneziawg_go:
  file.managed:
    - name: /var/home/neg/.local/bin/amneziawg-go
    - source: /var/mnt/one/pkg/cache/amnezia/amneziawg-go-bin
    - mode: '0755'
    - user: neg
    - group: neg
    - require:
      - cmd: build_amnezia_all

install_amneziawg_tools:
  file.managed:
    - name: /var/home/neg/.local/bin/awg
    - source: /var/mnt/one/pkg/cache/amnezia/awg-bin
    - mode: '0755'
    - user: neg
    - group: neg
    - require:
      - cmd: build_amnezia_all

# Symlinks for sudo access
/usr/local/bin/amneziawg-go:
  file.symlink:
    - target: /var/home/neg/.local/bin/amneziawg-go
    - force: True
    - require:
      - file: install_amneziawg_go

/usr/local/bin/awg:
  file.symlink:
    - target: /var/home/neg/.local/bin/awg
    - force: True
    - require:
      - file: install_amneziawg_tools

install_amnezia_vpn:
  file.managed:
    - name: /var/home/neg/.local/bin/AmneziaVPN
    - source: /var/mnt/one/pkg/cache/amnezia/AmneziaVPN-bin
    - mode: '0755'
    - user: neg
    - group: neg
    - require:
      - cmd: build_amnezia_all

# Verification
verify_amneziawg_go:
  cmd.run:
    - name: /var/home/neg/.local/bin/amneziawg-go --version
    - require:
      - file: install_amneziawg_go

verify_awg:
  cmd.run:
    - name: /var/home/neg/.local/bin/awg --version
    - require:
      - file: install_amneziawg_tools

verify_amnezia_vpn:
  cmd.run:
    - name: ldd /var/home/neg/.local/bin/AmneziaVPN
    - require:
      - file: install_amnezia_vpn

/var/home/neg/.local/share/applications:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

amnezia_desktop_entry:
  file.managed:
    - name: /var/home/neg/.local/share/applications/amnezia-vpn.desktop
    - contents: |
        [Desktop Entry]
        Type=Application
        Name=AmneziaVPN (Source)
        Comment=Amnezia VPN Client (Self-built)
        Exec=/var/home/neg/.local/bin/AmneziaVPN
        Icon=amnezia-vpn
        Terminal=false
        Categories=Network;VPN;
    - user: neg
    - group: neg
    - require:
      - file: /var/home/neg/.local/share/applications
