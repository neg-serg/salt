%define debug_package %{nil}

Name:           pup
Version:        0.4.0
Release:        1%{?dist}
Summary:        HTML parser CLI

License:        MIT
URL:            https://github.com/ericchiang/pup
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
A command-line tool for processing HTML, like jq for HTML.

%prep
%setup -q -n pup-0.4.0

%build
go mod init github.com/ericchiang/pup
rm -rf vendor
go mod tidy
go build -ldflags="-s -w" -o pup .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 pup %{buildroot}%{_bindir}/pup

%files
%{_bindir}/pup

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.4.0-1
- Initial custom RPM build
