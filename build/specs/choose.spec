%define debug_package %{nil}

Name:           choose
Version:        1.3.7
Release:        1%{?dist}
Summary:        Human-friendly cut alternative

License:        GPL-3.0-or-later
URL:            https://github.com/theryangeary/choose
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
A human-friendly and fast alternative to cut and awk.

%prep
%setup -q -n choose-1.3.7

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/choose %{buildroot}%{_bindir}/choose

%files
%{_bindir}/choose

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 1.3.7-1
- Initial custom RPM build
