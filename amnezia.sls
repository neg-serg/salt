# Salt state for Amnezia build and deploy (Local User version)

/var/home/neg/src/amnezia_build:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

/var/home/neg/.local/bin:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

# Build AmneziaWG-go
build_amneziawg_go:
  cmd.run:
    - name: |
        podman run --rm -v /var/home/neg/src/amnezia_build:/build:Z registry.fedoraproject.org/fedora-toolbox:43 bash -c "
        dnf install -y git golang make && \
        rm -rf /build/amneziawg-go-src && \
        git clone https://github.com/amnezia-vpn/amneziawg-go.git /build/amneziawg-go-src && \
        cd /build/amneziawg-go-src && \
        make && \
        cp amneziawg-go /build/amneziawg-go-bin
        "
    - creates: /var/home/neg/src/amnezia_build/amneziawg-go-bin
    - require:
      - file: /var/home/neg/src/amnezia_build

install_amneziawg_go:
  file.managed:
    - name: /var/home/neg/.local/bin/amneziawg-go
    - source: /var/home/neg/src/amnezia_build/amneziawg-go-bin
    - mode: '0755'
    - user: neg
    - group: neg
    - require:
      - cmd: build_amneziawg_go

# Build AmneziaWG-tools
build_amneziawg_tools:
  cmd.run:
    - name: |
        podman run --rm -v /var/home/neg/src/amnezia_build:/build:Z registry.fedoraproject.org/fedora-toolbox:43 bash -c "
        dnf install -y git make gcc libmnl-devel && \
        rm -rf /build/amneziawg-tools-src && \
        git clone https://github.com/amnezia-vpn/amneziawg-tools.git /build/amneziawg-tools-src && \
        cd /build/amneziawg-tools-src/src && \
        make && \
        cp wg /build/awg-bin
        "
    - creates: /var/home/neg/src/amnezia_build/awg-bin
    - require:
      - file: /var/home/neg/src/amnezia_build

install_amneziawg_tools:
  file.managed:
    - name: /var/home/neg/.local/bin/awg
    - source: /var/home/neg/src/amnezia_build/awg-bin
    - mode: '0755'
    - user: neg
    - group: neg
    - require:
      - cmd: build_amneziawg_tools

# Build Amnezia-VPN Client (GUI)
build_amnezia_vpn:
  cmd.run:
    - name: |
        podman run --rm -v /var/home/neg/src/amnezia_build:/build:Z registry.fedoraproject.org/fedora-toolbox:43 bash -c "
        dnf install -y git cmake make gcc-c++ qt6-qtbase-devel qt6-qtsvg-devel \
            qt6-qtdeclarative-devel qt6-qttools-devel libmnl-devel libmount-devel \
            qt6-qt5compat-devel qt6-qtshadertools-devel qt6-qtmultimedia-devel \
            qt6-qtbase-static qt6-qtdeclarative-static && \
        rm -rf /build/amnezia-client-src && \
        git clone --recursive https://github.com/amnezia-vpn/amnezia-client.git /build/amnezia-client-src && \
        mkdir -p /build/amnezia-client-src/build && cd /build/amnezia-client-src/build && \
        cmake .. -DCMAKE_BUILD_TYPE=Release -DVERSION=2.1.2 && \
        make -j\$(nproc) && \
        cp AmneziaVPN /build/AmneziaVPN-bin
        "
    - creates: /var/home/neg/src/amnezia_build/AmneziaVPN-bin
    - timeout: 3600
    - require:
      - file: /var/home/neg/src/amnezia_build

install_amnezia_vpn:
  file.managed:
    - name: /var/home/neg/.local/bin/AmneziaVPN
    - source: /var/home/neg/src/amnezia_build/AmneziaVPN-bin
    - mode: '0755'
    - user: neg
    - group: neg
    - require:
      - cmd: build_amnezia_vpn

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
