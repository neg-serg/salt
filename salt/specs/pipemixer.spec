%define debug_package %{nil}

Name:           pipemixer
Version:        0.4.0
Release:        1%{?dist}
Summary:        TUI volume control app for PipeWire

License:        GPL-3.0-or-later
URL:            https://github.com/heather7283/pipemixer
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  pkgconf-pkg-config
BuildRequires:  pipewire-devel
BuildRequires:  ncurses-devel
BuildRequires:  inih-devel

%description
A TUI volume control application for PipeWire, inspired by pulsemixer and
pwvucontrol. Allows direct control of outputs, inputs, and currently played
media with the keyboard.

%prep
%setup -q -n pipemixer-%{version}

%build
meson setup build --prefix=/usr -Dshell-completions=true
ninja -C build

%install
DESTDIR=%{buildroot} ninja -C build install

%files
%{_bindir}/pipemixer
%{_datadir}/applications/com.github.pipemixer.desktop
%{_mandir}/man1/pipemixer.1*
%{_mandir}/man5/pipemixer.ini.5*
%{_datadir}/zsh/site-functions/_pipemixer

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.4.0-1
- Initial custom RPM build
