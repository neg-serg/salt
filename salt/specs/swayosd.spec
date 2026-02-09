%define debug_package %{nil}

Name:           swayosd
Version:        0.3.0
Release:        1%{?dist}
Summary:        OSD window for volume, brightness and capslock on Wayland

License:        GPL-3.0-or-later
URL:            https://github.com/ErikReider/SwayOSD
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  glib2-devel
BuildRequires:  sassc
BuildRequires:  gtk4-devel
BuildRequires:  gtk4-layer-shell-devel
BuildRequires:  pulseaudio-libs-devel
BuildRequires:  libinput-devel
BuildRequires:  libevdev-devel
BuildRequires:  systemd-devel

%description
A GTK-based on-screen display for Wayland compositors, showing indicators
for volume, brightness, capslock and other common actions.

%prep
%setup -q -n %{name}-%{version}

%build
meson setup build --prefix=/usr --buildtype release
ninja -C build

%install
DESTDIR=%{buildroot} ninja -C build install

%files
%{_bindir}/swayosd-server
%{_bindir}/swayosd-client
%{_bindir}/swayosd-libinput-backend
%{_libdir}/udev/rules.d/99-swayosd.rules
%{_datadir}/dbus-1/system.d/org.erikreider.swayosd.conf
%{_datadir}/dbus-1/system-services/org.erikreider.swayosd.service
%{_datadir}/polkit-1/rules.d/org.erikreider.swayosd.rules
%{_datadir}/polkit-1/actions/org.erikreider.swayosd.policy
%{_unitdir}/swayosd-libinput-backend.service
%dir %{_sysconfdir}/xdg/swayosd
%config(noreplace) %{_sysconfdir}/xdg/swayosd/config.toml
%config(noreplace) %{_sysconfdir}/xdg/swayosd/backend.toml
%config(noreplace) %{_sysconfdir}/xdg/swayosd/style.css

%changelog
* Sun Feb 09 2026 neg-serg <neg-serg@example.com> - 0.3.0-1
- Initial custom RPM build
