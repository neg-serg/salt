%define debug_package %{nil}

Name:           dive
Version:        0.13.1
Release:        1%{?dist}
Summary:        Docker image layer explorer

License:        MIT
URL:            https://github.com/wagoodman/dive
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
Explore each layer in a Docker image to discover ways to shrink it.

%prep
%setup -q -n dive-0.13.1

%build
go build -ldflags="-s -w" -o dive-bin .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 dive-bin %{buildroot}%{_bindir}/dive

%files
%{_bindir}/dive

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.13.1-1
- Initial custom RPM build
