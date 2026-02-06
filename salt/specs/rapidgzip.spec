%define debug_package %{nil}

Name:           rapidgzip
Version:        0.16.0
Release:        1%{?dist}
Summary:        Parallel gzip decompressor

License:        MIT
URL:            https://github.com/mxmlnkn/rapidgzip
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  python3-devel
BuildRequires:  python3-pip
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
BuildRequires:  gcc-c++
BuildRequires:  nasm
BuildRequires:  git

Requires:       python3

%description
Parallel gzip decompressor with high-speed random access support.

%prep
%setup -q -n rapidgzip-%{version}

%build
# Nothing to do here

%install
cd python/rapidgzip
pip3 install --no-deps --prefix=/usr --root=%{buildroot} .

%files
%{_bindir}/rapidgzip
%{python3_sitearch}/rapidgzip*

%changelog
* Thu Feb 06 2026 neg-serg <neg-serg@example.com> - 0.16.0-1
- Initial custom RPM build
