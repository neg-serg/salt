%define debug_package %{nil}

Name:           croc
Version:        10.3.1
Release:        1%{?dist}
Summary:        Easily and securely send things from one computer to another

License:        MIT
URL:            https://github.com/schollz/croc
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
croc is a tool that allows any two computers to simply and securely
transfer files and folders. It uses a relay to establish a connection
and provides end-to-end encryption using PAKE.

%prep
%setup -q -n croc-%{version}

%build
go build -ldflags="-s -w" -o croc .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 croc %{buildroot}%{_bindir}/croc

%files
%{_bindir}/croc

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 10.3.1-1
- Initial custom RPM build
