%define debug_package %{nil}

Name:           zfxtop
Version:        0.3.2
Release:        1%{?dist}
Summary:        TUI system monitor

License:        MIT
URL:            https://github.com/ssleert/zfxtop
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
A fetch-like system monitor with a TUI.

%prep
%setup -q -n zfxtop-0.3.2

%build
go build -ldflags="-s -w" -o zfxtop ./cmd/zfxtop

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 zfxtop %{buildroot}%{_bindir}/zfxtop

%files
%{_bindir}/zfxtop

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.3.2-1
- Initial custom RPM build
