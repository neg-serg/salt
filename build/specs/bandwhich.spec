%define debug_package %{nil}

Name:           bandwhich
Version:        0.23.1
Release:        1%{?dist}
Summary:        Terminal bandwidth utilization tool per process

License:        MIT
URL:            https://github.com/imsnif/bandwhich
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
Display current network utilization by process, connection and remote IP/hostname.

%prep
%setup -q -n bandwhich-%{version}

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/bandwhich %{buildroot}%{_bindir}/bandwhich

%files
%{_bindir}/bandwhich

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 0.23.1-1
- Initial custom RPM build
