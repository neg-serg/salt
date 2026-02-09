%define debug_package %{nil}

Name:           jujutsu
Version:        0.38.0
Release:        1%{?dist}
Summary:        Git-compatible VCS

License:        Apache-2.0
URL:            https://github.com/jj-vcs/jj
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git
BuildRequires:  openssl-devel
BuildRequires:  pkgconf-pkg-config
BuildRequires:  cmake

%description
A Git-compatible version control system with a simpler interface.

%prep
%setup -q -n jujutsu-0.38.0

%build
cargo build --release --bin jj

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/jj %{buildroot}%{_bindir}/jj

%files
%{_bindir}/jj

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.38.0-1
- Initial custom RPM build
