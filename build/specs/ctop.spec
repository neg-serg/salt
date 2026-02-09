%define debug_package %{nil}

Name:           ctop
Version:        0.7.7
Release:        1%{?dist}
Summary:        Container metrics TUI

License:        MIT
URL:            https://github.com/bcicen/ctop
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
Top-like interface for container metrics.

%prep
%setup -q -n ctop-0.7.7

%build
go build -ldflags="-s -w" -o ctop .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 ctop %{buildroot}%{_bindir}/ctop

%files
%{_bindir}/ctop

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.7.7-1
- Initial custom RPM build
