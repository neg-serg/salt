%define debug_package %{nil}

Name:           gist
Version:        6.0.0
Release:        1%{?dist}
Summary:        GitHub gist CLI
BuildArch:      noarch

License:        MIT
URL:            https://github.com/defunkt/gist
Source0:        %{name}-%{version}.tar.gz

Requires:       ruby

%description
Command-line interface for creating and managing GitHub gists.

%prep
%setup -q -n gist-%{version}

%build
# Build standalone executable
rake standalone

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 build/gist %{buildroot}%{_bindir}/gist

%files
%{_bindir}/gist

%changelog
* Fri Feb 07 2026 neg-serg <neg-serg@example.com> - 6.0.0-1
- Initial custom RPM build
