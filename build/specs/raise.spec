%define debug_package %{nil}

Name:           raise
Version:        0.1.0
Release:        1%{?dist}
Summary:        Run or raise for Hyprland (neg-serg fork)

License:        MIT
URL:            https://github.com/neg-serg/raise
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
Run or raise utility for Hyprland window manager.
Raises/focuses an existing window if it matches specified criteria,
cycles to the next matching window, or launches a new one.

%prep
%setup -q -n raise-%{version}

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/raise %{buildroot}%{_bindir}/raise

%files
%{_bindir}/raise

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.1.0-1
- Initial custom RPM build
