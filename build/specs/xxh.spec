%define debug_package %{nil}

Name:           xxh
Version:        0.8.14
Release:        1%{?dist}
Summary:        SSH with local shell config
BuildArch:      noarch

License:        BSD
URL:            https://github.com/xxh/xxh
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
Requires:       python3
Requires:       python3-pexpect
Requires:       python3-pyyaml

%description
Bring your favorite shell wherever you go through SSH.

%prep
%setup -q -n xxh-%{version}

%build
# Nothing to compile

%install
pip3 install --no-deps --prefix=/usr --root=%{buildroot} .

%files
%{_bindir}/xxh
%{_bindir}/xxh.zsh
%{_bindir}/xxh.xsh
%{_bindir}/xxh.bash
%{python3_sitelib}/xxh_xxh/
%{python3_sitelib}/xxh_xxh-*

%changelog
* Thu Feb 06 2026 neg-serg <neg-serg@example.com> - 0.8.14-1
- Initial custom RPM build
