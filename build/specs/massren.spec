%define debug_package %{nil}

Name:           massren
Version:        1.5.6
Release:        1%{?dist}
Summary:        Mass rename utility using your favorite text editor

License:        MIT
URL:            https://github.com/laurent22/massren
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
massren is a command line tool that allows you to rename multiple files using
your favorite text editor.

%prep
%setup -q -n massren-%{version}

%build
go build -o massren .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 massren %{buildroot}%{_bindir}/massren

%files
%{_bindir}/massren

%changelog
* Thu Feb 05 2026 neg-serg <neg-serg@example.com> - 1.5.6-1
- Initial custom RPM build
