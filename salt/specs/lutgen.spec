%define debug_package %{nil}

Name:           lutgen
Version:        0.12.1
Release:        1%{?dist}
Summary:        LUT generator for color grading

License:        MIT
URL:            https://github.com/ozwaldorf/lutgen-rs
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
A LUT generator for color grading with palette-based color mapping.

%prep
%setup -q -n lutgen-%{version}

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/lutgen %{buildroot}%{_bindir}/lutgen

%files
%{_bindir}/lutgen

%changelog
* Fri Feb 07 2026 neg-serg <neg-serg@example.com> - 0.12.1-1
- Initial custom RPM build
