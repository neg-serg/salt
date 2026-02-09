%define debug_package %{nil}

Name:           xdg-desktop-portal-termfilechooser
Version:        0.4.0
Release:        1%{?dist}
Summary:        XDG desktop portal backend for terminal file choosers

License:        MIT
URL:            https://github.com/GermainZ/xdg-desktop-portal-termfilechooser
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  inih-devel
BuildRequires:  systemd-devel
BuildRequires:  scdoc

%description
A portal backend that uses a terminal file manager (like yazi, ranger, etc.)
as a file chooser dialog via the XDG Desktop Portal D-Bus interface.

%prep
%setup -q -n %{name}-%{version}

%build
meson setup build --prefix=/usr -Dsd-bus-provider=libsystemd
ninja -C build

%install
DESTDIR=%{buildroot} ninja -C build install

%files
%{_libexecdir}/xdg-desktop-portal-termfilechooser
%{_datadir}/xdg-desktop-portal/portals/termfilechooser.portal
%{_datadir}/dbus-1/services/org.freedesktop.impl.portal.desktop.termfilechooser.service
%{_datadir}/xdg-desktop-portal-termfilechooser/ranger-wrapper.sh
%{_mandir}/man5/xdg-desktop-portal-termfilechooser.5*

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 0.4.0-1
- Initial custom RPM build
