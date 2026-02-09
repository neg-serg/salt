%define debug_package %{nil}

Name:           richcolors
Version:        0.1.0
Release:        1%{?dist}
Summary:        CLI that renders color palette images from hex code files
BuildArch:      noarch

License:        Unlicense
URL:            https://github.com/Rizen54/richcolors
Source0:        %{name}-%{version}.tar.gz

Requires:       python3
Requires:       python3-pillow

%description
A CLI tool that renders color palette images from hex code files.
Parses hex color codes from a text file and generates a visual palette image.

%prep
%setup -q -n richcolors-%{version}

%build
# Nothing to build - pure Python script

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 richcolors %{buildroot}%{_bindir}/richcolors

%files
%{_bindir}/richcolors

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.1.0-1
- Initial custom RPM build
