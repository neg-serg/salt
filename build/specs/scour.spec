%define debug_package %{nil}

Name:           scour
Version:        0.38.2
Release:        1%{?dist}
Summary:        SVG optimizer
BuildArch:      noarch

License:        Apache-2.0
URL:            https://github.com/scour-project/scour
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
Requires:       python3
Requires:       python3-six

%description
An SVG scrubber that optimizes SVG files by removing unnecessary elements.

%prep
%setup -q -n scour-%{version}

%build
# Nothing to compile

%install
mkdir -p %{buildroot}%{python3_sitelib}
mkdir -p %{buildroot}%{_bindir}
cp -a scour %{buildroot}%{python3_sitelib}/scour
cat > %{buildroot}%{_bindir}/scour << 'WRAPPER'
#!/usr/bin/python3
from scour.scour import run
run()
WRAPPER
chmod 0755 %{buildroot}%{_bindir}/scour

%files
%{_bindir}/scour
%{python3_sitelib}/scour/

%changelog
* Thu Feb 06 2026 neg-serg <neg-serg@example.com> - 0.38.2-1
- Initial custom RPM build
