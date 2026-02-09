%define debug_package %{nil}

Name:           taplo
Version:        0.10.0
Release:        1%{?dist}
Summary:        TOML toolkit and linter

License:        MIT
URL:            https://github.com/tamasfe/taplo
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git
BuildRequires:  openssl-devel
BuildRequires:  pkgconf-pkg-config

%description
A TOML toolkit with a CLI for formatting, linting, and language server support.

%prep
%setup -q -n taplo-%{version}

%build
cargo build --release -p taplo-cli

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/taplo %{buildroot}%{_bindir}/taplo

%files
%{_bindir}/taplo

%changelog
* Fri Feb 07 2026 neg-serg <neg-serg@example.com> - 0.10.0-1
- Initial custom RPM build
