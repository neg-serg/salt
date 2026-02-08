%define debug_package %{nil}

Name:           quickshell
Version:        0.2.1
Release:        1%{?dist}
Summary:        Qt6/QML desktop shell toolkit for Wayland compositors

License:        LGPL-3.0-only AND GPL-3.0-only
URL:            https://git.outfoxxed.me/quickshell/quickshell
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake >= 3.20
BuildRequires:  ninja-build
BuildRequires:  gcc-c++
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6ShaderTools)
BuildRequires:  cmake(Qt6WaylandClient)
BuildRequires:  qt6-qtbase-private-devel
BuildRequires:  spirv-tools
BuildRequires:  pkgconfig(CLI11)
BuildRequires:  pkgconfig(jemalloc)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  pkgconfig(wayland-protocols)
BuildRequires:  pkgconfig(libdrm)
BuildRequires:  pkgconfig(gbm)
BuildRequires:  pkgconfig(egl)
BuildRequires:  pkgconfig(libpipewire-0.3)
BuildRequires:  pkgconfig(pam)
BuildRequires:  pkgconfig(polkit-agent-1)
BuildRequires:  pkgconfig(polkit-gobject-1)
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  pkgconfig(gobject-2.0)
BuildRequires:  pkgconfig(xcb)

%description
Quickshell is a Qt6/QML based desktop shell toolkit for Wayland compositors.
It provides deep integration with Hyprland, Sway/i3, and other wlroots-based
compositors through its QML API.

%prep
%setup -q -n quickshell-%{version}

%build
cmake -GNinja -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=%{_prefix} \
  -DBUILD_SHARED_LIBS=OFF \
  -DCRASH_REPORTER=OFF \
  -DINSTALL_QML_PREFIX=%{_lib}/qt6/qml

cmake --build build

%install
DESTDIR=%{buildroot} cmake --install build

%files
%{_bindir}/quickshell
%{_bindir}/qs
%{_datadir}/applications/org.quickshell.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.quickshell.svg
%{_libdir}/qt6/qml/Quickshell/

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 0.2.1-1
- Initial custom RPM build
