%define debug_package %{nil}

Name:           cmake-language-server
Version:        0.1.11
Release:        1%{?dist}
Summary:        CMake Language Server Protocol implementation
BuildArch:      noarch

License:        MIT
URL:            https://github.com/regen100/cmake-language-server
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
Requires:       python3

%description
CMake LSP implementation based on pygls.

%prep
%setup -q -n %{name}-%{version}

%build
# Nothing to compile

%install
pip3 install --ignore-requires-python --no-warn-script-location --prefix=/usr --root=%{buildroot} .

%files
%{_bindir}/cmake-language-server
%{python3_sitelib}/cmake_language_server/
%{python3_sitelib}/cmake_language_server-*.dist-info/
%{python3_sitelib}/pygls/
%{python3_sitelib}/pygls-*.dist-info/
%{python3_sitelib}/lsprotocol/
%{python3_sitelib}/lsprotocol-*.dist-info/
%{python3_sitelib}/cattrs/
%{python3_sitelib}/cattrs-*.dist-info/
%{python3_sitelib}/cattr/
%{python3_sitelib}/attrs/
%{python3_sitelib}/attrs-*.dist-info/
%{python3_sitelib}/attr/
%{python3_sitelib}/typing_extensions*

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 0.1.11-1
- Initial custom RPM build
