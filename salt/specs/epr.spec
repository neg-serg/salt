%define debug_package %{nil}

Name:           epr
Version:        2.4.15
Release:        1%{?dist}
Summary:        Terminal EPUB reader
BuildArch:      noarch

License:        MIT
URL:            https://github.com/wustho/epr
Source0:        %{name}-%{version}.tar.gz

Requires:       python3

%description
Terminal EPUB reader with keyboard navigation.

%prep
%setup -q -n epr-2.4.15

%build
# Nothing to build - Python script

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 epr.py %{buildroot}%{_bindir}/epr

%files
%{_bindir}/epr

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 2.4.15-1
- Initial custom RPM build
