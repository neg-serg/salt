%define debug_package %{nil}

Name:           xh
Version:        0.25.3
Release:        1%{?dist}
Summary:        Friendly and fast tool for sending HTTP requests

License:        MIT
URL:            https://github.com/ducaale/xh
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
xh is a friendly and fast tool for sending HTTP requests.
It reimplements as much as possible of HTTPie's excellent design.

%prep
%setup -q -n xh-%{version}

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/xh %{buildroot}%{_bindir}/xh

%files
%{_bindir}/xh

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 0.25.3-1
- Initial custom RPM build
