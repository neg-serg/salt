%define debug_package %{nil}

Name:           grex
Version:        1.4.6
Release:        1%{?dist}
Summary:        Regex generator from examples

License:        Apache-2.0
URL:            https://github.com/pemistahl/grex
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
Generates regular expressions from user-provided test cases.

%prep
%setup -q -n grex-1.4.6

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/grex %{buildroot}%{_bindir}/grex

%files
%{_bindir}/grex

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 1.4.6-1
- Initial custom RPM build
