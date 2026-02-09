%define debug_package %{nil}

Name:           doggo
Version:        1.1.2
Release:        1%{?dist}
Summary:        Command-line DNS client for humans

License:        GPL-3.0
URL:            https://github.com/mr-karan/doggo
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
doggo is a modern command-line DNS client (like dig) written in Golang.
Features include human-readable output, JSON support, and multiple transport protocols.

%prep
%setup -q -n doggo-%{version}

%build
go build -ldflags="-s -w" -o doggo ./cmd/doggo

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 doggo %{buildroot}%{_bindir}/doggo

%files
%{_bindir}/doggo

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 1.1.2-1
- Initial custom RPM build
