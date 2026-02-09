%define debug_package %{nil}

Name:           curlie
Version:        1.8.2
Release:        1%{?dist}
Summary:        The power of curl, the ease of use of httpie

License:        MIT
URL:            https://github.com/rs/curlie
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
Curlie is a frontend to curl that adds the ease of use of httpie,
without compromising on features and performance.

%prep
%setup -q -n curlie-%{version}

%build
go build -ldflags="-s -w" -o curlie .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 curlie %{buildroot}%{_bindir}/curlie

%files
%{_bindir}/curlie

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 1.8.2-1
- Initial custom RPM build
