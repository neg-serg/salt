#!/bin/bash
set -e

BUILD_DIR="/var/home/neg/src/amnezia_build"
mkdir -p "$BUILD_DIR"

echo "Starting Amnezia build in Podman..."

podman run --rm \
    -v "$BUILD_DIR":/build:Z \
    registry.fedoraproject.org/fedora-toolbox:43 bash -c "
    set -e
    echo '--- Installing dependencies ---'
    git config --global --add safe.directory '*'
    dnf install -y --disablerepo=fedora-cisco-openh264 --setopt=install_weak_deps=False \
        git cmake make gcc-c++ \
        qt6-qtbase-devel qt6-qtsvg-devel qt6-qtdeclarative-devel qt6-qttools-devel \
        qt6-qt5compat-devel qt6-qtshadertools-devel qt6-qtmultimedia-devel \
        qt6-qtremoteobjects-devel qt6-qtwayland-devel \
        libmnl-devel libmount-devel libsecret-devel openssl-devel zlib-devel \
        dbus-devel polkit-devel systemd-devel \
        glibc-static libstdc++-static \
        qt6-qtbase-static qt6-qtdeclarative-static \
        rpm-build rpm-devel elfutils-libelf-devel dkms

    echo '--- 1. Building Amnezia-VPN Client ---'
    if [ ! -f /build/AmneziaVPN-bin ]; then
        rm -rf /build/amnezia-client-src
        git clone --recursive https://github.com/amnezia-vpn/amnezia-client.git /build/amnezia-client-src
        mkdir -p /build/amnezia-client-src/build
        cd /build/amnezia-client-src/build
        cmake .. -DCMAKE_BUILD_TYPE=Release -DVERSION=2.1.2
        make -j\$(nproc)
        cp client/AmneziaVPN /build/AmneziaVPN-bin
    else
        echo 'AmneziaVPN-bin already exists, skipping build.'
    fi

    echo '--- 2. Building amneziawg-tools RPM ---'
    rm -rf /build/amneziawg-tools-src
    git clone https://github.com/amnezia-vpn/amneziawg-tools.git /build/amneziawg-tools-src
    cd /build/amneziawg-tools-src
    # Create tarball for RPM
    VERSION=1.0.20240201
    cd ..
    tar -czf amneziawg-tools-\$VERSION.tar.gz amneziawg-tools-src
    mkdir -p ~/rpmbuild/{SOURCES,SPECS}
    cp amneziawg-tools-\$VERSION.tar.gz ~/rpmbuild/SOURCES/
    
    # Simple spec for tools
    cat > ~/rpmbuild/SPECS/amneziawg-tools.spec <<EOF
Name: amneziawg-tools
Version: \$VERSION
Release: 1%{?dist}
Summary: Tools for AmneziaWG
License: GPLv2
Source0: amneziawg-tools-%{version}.tar.gz
BuildRequires: make gcc
%description
Tools for AmneziaWG.
%prep
%setup -q -n amneziawg-tools-src
%build
make -C src
%install
make -C src install DESTDIR=%{buildroot} BINDIR=%{_bindir} MANDIR=%{_mandir}
%files
%{_bindir}/awg
%{_bindir}/awg-quick
%{_mandir}/man8/awg.8*
%{_mandir}/man8/awg-quick.8*
/usr/lib/systemd/system/awg-quick.target
/usr/lib/systemd/system/awg-quick@.service
/usr/share/bash-completion/completions/awg
/usr/share/bash-completion/completions/awg-quick
EOF
    rpmbuild -bb ~/rpmbuild/SPECS/amneziawg-tools.spec
    cp ~/rpmbuild/RPMS/x86_64/amneziawg-tools-*.rpm /build/

    echo '--- 3. Building amneziawg-dkms RPM ---'
    rm -rf /build/amneziawg-dkms-src
    git clone https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git /build/amneziawg-dkms-src
    cd /build/amneziawg-dkms-src
    VERSION=1.0.0
    cd ..
    tar -czf amneziawg-\$VERSION.tar.gz amneziawg-dkms-src
    cp amneziawg-\$VERSION.tar.gz ~/rpmbuild/SOURCES/
    
    # DKMS spec
    cat > ~/rpmbuild/SPECS/amneziawg-dkms.spec <<EOF
Name: amneziawg-dkms
Version: \$VERSION
Release: 1%{?dist}
Summary: AmneziaWG kernel module source for DKMS
License: GPLv2
Source0: amneziawg-%{version}.tar.gz
BuildArch: noarch
Requires: dkms kernel-devel
%description
AmneziaWG kernel module source for DKMS.
%prep
%setup -q -n amneziawg-dkms-src
%install
mkdir -p %{buildroot}/usr/src/amneziawg-%{version}
cp -r * %{buildroot}/usr/src/amneziawg-%{version}/
cat > %{buildroot}/usr/src/amneziawg-%{version}/dkms.conf <<EOT
PACKAGE_NAME="amneziawg"
PACKAGE_VERSION="%{version}"
BUILT_MODULE_NAME[0]="amneziawg"
DEST_MODULE_LOCATION[0]="/extra"
AUTOINSTALL="yes"
EOT
%files
/usr/src/amneziawg-%{version}/
EOF
    rpmbuild -bb ~/rpmbuild/SPECS/amneziawg-dkms.spec
    cp ~/rpmbuild/RPMS/noarch/amneziawg-dkms-*.rpm /build/

    echo 'Build finished successfully!'
"
