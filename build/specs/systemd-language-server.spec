%define debug_package %{nil}
# Filter auto-generated lxml requirement — system python3-lxml is v6.x but
# pip metadata pins lxml>=5,<6; we depend on python3-lxml explicitly instead
%global __requires_exclude python3.*dist\\(lxml\\)|python3.*dist\\(pygls\\)|python3.*dist\\(lsprotocol\\)|python3.*dist\\(cattrs\\)|python3.*dist\\(attrs\\)|python3.*dist\\(typing.extensions\\)

Name:           systemd-language-server
Version:        0.3.5
Release:        1%{?dist}
Summary:        Language Server Protocol implementation for systemd unit files

License:        MIT
URL:            https://github.com/psacawa/systemd-language-server
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
BuildRequires:  gcc
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
Requires:       python3
Requires:       python3-lxml
Requires:       cmake-language-server

%description
Systemd unit file language server with autocompletion and hover support.

%prep
%setup -q -n %{name}-%{version}

%build
# Nothing to compile

%install
pip3 install --no-warn-script-location --prefix=/usr --root=%{buildroot} .
# Remove bundled lxml to avoid file conflict with system python3-lxml
rm -rf %{buildroot}%{python3_sitearch}/lxml*
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
%{_bindir}/systemd-language-server
%{python3_sitelib}/systemd_language_server/
%{python3_sitelib}/systemd_language_server-*.dist-info/

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 0.3.5-1
- Initial custom RPM build
