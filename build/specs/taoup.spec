%define debug_package %{nil}

Name:           taoup
Version:        1.1.23
Release:        1%{?dist}
Summary:        The Art of Unix Programming wisdom quotes
BuildArch:      noarch

License:        GPL-3.0-only
URL:            https://github.com/globalcitizen/taoup
Source0:        %{name}-%{version}.tar.gz

Requires:       ruby
Requires:       rubygem-ansi

%description
Displays random quotes from Eric S. Raymond's "The Art of Unix Programming"
and other classic Unix wisdom. Can be used as a login fortune replacement.

%prep
%setup -q -n taoup-%{version}

%build
# Nothing to build — Ruby script

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 taoup %{buildroot}%{_bindir}/taoup

%files
%{_bindir}/taoup

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 1.1.23-1
- Initial custom RPM build
