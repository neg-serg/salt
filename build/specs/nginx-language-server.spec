%define debug_package %{nil}
# Filter auto-generated requirements for shared deps (provided by cmake-language-server)
%global __requires_exclude python3.*dist\\(pygls\\)|python3.*dist\\(lsprotocol\\)|python3.*dist\\(cattrs\\)|python3.*dist\\(attrs\\)|python3.*dist\\(typing.extensions\\)

Name:           nginx-language-server
Version:        0.9.0
Release:        1%{?dist}
Summary:        Language Server Protocol implementation for nginx config files
# Not noarch: pydantic has C extensions that install to sitearch

License:        GPL-3.0
URL:            https://github.com/pappasam/nginx-language-server
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
Requires:       python3
Requires:       cmake-language-server

%description
Nginx language server with autocompletion and hover support.

%prep
%setup -q -n %{name}-%{version}

%build
# Nothing to compile

%install
pip3 install --ignore-requires-python --no-warn-script-location --prefix=/usr --root=%{buildroot} .
# Remove shared deps (provided by cmake-language-server RPM)
rm -rf %{buildroot}%{python3_sitelib}/pygls*
rm -rf %{buildroot}%{python3_sitelib}/lsprotocol*
rm -rf %{buildroot}%{python3_sitelib}/cattrs*
rm -rf %{buildroot}%{python3_sitelib}/cattr
rm -rf %{buildroot}%{python3_sitelib}/attrs*
rm -rf %{buildroot}%{python3_sitelib}/attr
rm -rf %{buildroot}%{python3_sitelib}/typing_extensions*
rm -rf %{buildroot}%{python3_sitelib}/__pycache__/typing_extensions*

%files
%{_bindir}/nginx-language-server
%{python3_sitelib}/nginx_language_server/
%{python3_sitelib}/nginx_language_server-*.dist-info/
%{_bindir}/crossplane
%{python3_sitelib}/crossplane/
%{python3_sitelib}/crossplane-*.dist-info/
%{python3_sitearch}/pydantic/
%{python3_sitearch}/pydantic-*.dist-info/

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 0.9.0-1
- Initial custom RPM build
