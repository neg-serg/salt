%define debug_package %{nil}

Name:           scc
Version:        3.6.0
Release:        1%{?dist}
Summary:        Fast code counter

License:        MIT
URL:            https://github.com/boyter/scc
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
A very fast accurate code counter with complexity calculations.

%prep
%setup -q -n scc-3.6.0

%build
go build -ldflags="-s -w" -o scc .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 scc %{buildroot}%{_bindir}/scc

%files
%{_bindir}/scc

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 3.6.0-1
- Initial custom RPM build
