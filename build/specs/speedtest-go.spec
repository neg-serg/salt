%define debug_package %{nil}

Name:           speedtest-go
Version:        1.7.10
Release:        1%{?dist}
Summary:        CLI and Go API to test internet speed using speedtest.net

License:        MIT
URL:            https://github.com/showwin/speedtest-go
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
speedtest-go is a pure Go implementation of speedtest.net client.
Features multi-server testing, JSON output, and can be used as a library.

%prep
%setup -q -n speedtest-go-%{version}

%build
go build -ldflags="-s -w" -o speedtest-go .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 speedtest-go %{buildroot}%{_bindir}/speedtest-go

%files
%{_bindir}/speedtest-go

%changelog
* Tue Feb 11 2026 neg-serg <neg-serg@example.com> - 1.7.10-1
- Initial custom RPM build
