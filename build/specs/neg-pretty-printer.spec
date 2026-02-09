%define debug_package %{nil}

Name:           neg-pretty-printer
Version:        0.1.0
Release:        1%{?dist}
Summary:        Custom pretty-printer utilities (colors + file info)
BuildArch:      noarch

License:        Unlicense
URL:            https://github.com/neg-serg
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel

Requires:       python3
Requires:       python3-colored

%description
Custom pretty-printer utilities for scripts. Provides PrettyPrinter
(color helpers and wrappers) and FileInfoPrinter (file info/length printer).
CLI tool: ppinfo.

%prep
%setup -q -n neg-pretty-printer-%{version}

%build
python3 -m pip wheel --no-deps --wheel-dir dist .

%install
python3 -m pip install --no-deps --prefix=/usr --root=%{buildroot} dist/*.whl

%files
%{_bindir}/ppinfo
%{python3_sitelib}/neg_pretty_printer/
%{python3_sitelib}/pretty_printer/
%{python3_sitelib}/neg_pretty_printer-%{version}.dist-info/

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.1.0-1
- Initial custom RPM build
