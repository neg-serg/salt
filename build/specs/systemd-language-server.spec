%define debug_package %{nil}

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
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
Requires:       python3

%description
Systemd unit file language server with autocompletion and hover support.

%prep
%setup -q -n %{name}-%{version}

%build
# Nothing to compile

%install
pip3 install --no-warn-script-location --prefix=/usr --root=%{buildroot} .

%files
%{_bindir}/systemd-language-server
%{python3_sitelib}/systemd_language_server/
%{python3_sitelib}/systemd_language_server-*.dist-info/
%{python3_sitelib}/pygls/
%{python3_sitelib}/pygls-*.dist-info/
%{python3_sitelib}/lsprotocol/
%{python3_sitelib}/lsprotocol-*.dist-info/
%{python3_sitelib}/cattrs/
%{python3_sitelib}/cattrs-*.dist-info/
%{python3_sitelib}/attrs/
%{python3_sitelib}/attrs-*.dist-info/
%{python3_sitelib}/attr/
%{python3_sitearch}/lxml/
%{python3_sitearch}/lxml-*.dist-info/

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 0.3.5-1
- Initial custom RPM build
