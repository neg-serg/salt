Name:           duf
Version:        0.9.1
Release:        1%{?dist}
Summary:        Disk Usage/Free Utility - a better df alternative (neg-serg custom build)

License:        MIT
URL:            https://github.com/neg-serg/duf
Source0:        %{name}-%{version}.tar.gz # Placeholder, source will be cloned

BuildRequires:  golang
BuildRequires:  git

%description
Duf is a disk usage utility that provides a better overview of disk usage.
This is a custom build from neg-serg's fork, including specific features or fixes.

%prep
%setup -q -n duf-%{version}

%build
# Build duf
go build -ldflags="-s -w -X main.Version=%{version}" -o duf-bin .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 duf-bin %{buildroot}%{_bindir}/duf

%files
%{_bindir}/duf

%changelog
* %{__date} neg-serg <neg-serg@example.com> - 0.2.0-1
- Initial custom RPM build
