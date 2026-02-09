%define debug_package %{nil}

Name:           viu
Version:        1.6.1
Release:        1%{?dist}
Summary:        Terminal image viewer

License:        MIT
URL:            https://github.com/atanunq/viu
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
A small command-line application to view images from the terminal.

%prep
%setup -q -n viu-1.6.1

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/viu %{buildroot}%{_bindir}/viu

%files
%{_bindir}/viu

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 1.6.1-1
- Initial custom RPM build
