%define debug_package %{nil}

Name:           rustnet
Version:        1.0.0
Release:        1%{?dist}
Summary:        Cross-platform network monitoring terminal UI tool

License:        Apache-2.0
URL:            https://github.com/domcyrus/rustnet
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git
BuildRequires:  libpcap-devel

%description
A cross-platform network monitoring terminal UI tool with real-time
visibility into network connections, deep packet inspection and
process attribution.

%prep
%setup -q -n rustnet-%{version}

%build
cargo build --release --no-default-features --features landlock

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/rustnet %{buildroot}%{_bindir}/rustnet

%files
%{_bindir}/rustnet

%changelog
* Wed Feb 12 2026 neg-serg <neg-serg@example.com> - 1.0.0-1
- Initial custom RPM build
