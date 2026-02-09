%define debug_package %{nil}

Name:           git-filter-repo
Version:        2.47.0
Release:        1%{?dist}
Summary:        Git history rewriting tool
BuildArch:      noarch

License:        MIT
URL:            https://github.com/newren/git-filter-repo
Source0:        %{name}-%{version}.tar.gz

Requires:       python3

%description
Versatile tool for rewriting git history.

%prep
%setup -q -n git-filter-repo-2.47.0

%build
# Nothing to build - Python script

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 git-filter-repo %{buildroot}%{_bindir}/git-filter-repo

%files
%{_bindir}/git-filter-repo

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 2.47.0-1
- Initial custom RPM build
