%define debug_package %{nil}

Name:           carapace
Version:        1.6.1
Release:        1%{?dist}
Summary:        Multi-shell multi-command argument completer

License:        MIT
URL:            https://github.com/carapace-sh/carapace-bin
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
Carapace provides argument completion for multiple CLI commands in multiple shells.

%prep
%setup -q -n carapace-%{version}

%build
go generate ./cmd/carapace/...
go build -ldflags="-s -w" -o carapace ./cmd/carapace

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 carapace %{buildroot}%{_bindir}/carapace

%files
%{_bindir}/carapace

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 1.6.1-1
- Initial custom RPM build
