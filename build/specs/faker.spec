%define debug_package %{nil}

Name:           faker
Version:        40.4.0
Release:        1%{?dist}
Summary:        Generate fake data from the command line
BuildArch:      noarch

License:        MIT
URL:            https://github.com/joke2k/faker
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
Requires:       python3

%description
Faker is a Python package that generates fake data for you. The CLI
provides commands for generating addresses, names, text, and more.

%prep
%setup -q -n %{name}-%{version}

%build
# Nothing to compile

%install
pip3 install --ignore-requires-python --no-warn-script-location --prefix=/usr --root=%{buildroot} .

%files
%{_bindir}/faker
%{python3_sitelib}/faker/
%{python3_sitelib}/faker-*.dist-info/

%changelog
* Tue Feb 10 2026 neg-serg <neg-serg@example.com> - 40.4.0-1
- Initial custom RPM build
