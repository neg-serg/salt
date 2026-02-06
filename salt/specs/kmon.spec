%define debug_package %{nil}

Name:           kmon
Version:        1.7.1
Release:        1%{?dist}
Summary:        Linux kernel module monitor TUI

License:        GPL-3.0-or-later
URL:            https://github.com/orhun/kmon
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
Linux kernel manager and activity monitor with a TUI.

%prep
%setup -q -n kmon-1.7.1

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/kmon %{buildroot}%{_bindir}/kmon

%files
%{_bindir}/kmon

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 1.7.1-1
- Initial custom RPM build
