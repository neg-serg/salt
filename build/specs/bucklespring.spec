%define debug_package %{nil}

Name:           bucklespring
Version:        1.5.1
Release:        1%{?dist}
Summary:        Nostalgia buckling spring keyboard sound

License:        GPL-2.0-only
URL:            https://github.com/zevv/bucklespring
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  pkgconf-pkg-config
BuildRequires:  openal-soft-devel
BuildRequires:  alure-devel
BuildRequires:  libX11-devel
BuildRequires:  libXtst-devel

Requires:       openal-soft
Requires:       alure

%description
Nostalgia buckling spring keyboard sound with audio from a real IBM Model-M
keyboard. Hooks into the keyboard to emit a mechanical keyboard sound for
every key pressed and released.

%prep
%setup -q -n bucklespring-%{version}

%build
make %{?_smp_mflags} PATH_AUDIO=%{_datadir}/bucklespring/wav

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/bucklespring
install -m 0755 buckle %{buildroot}%{_bindir}/buckle
cp -r wav %{buildroot}%{_datadir}/bucklespring/

%files
%{_bindir}/buckle
%{_datadir}/bucklespring/

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 1.5.1-1
- Initial custom RPM build
