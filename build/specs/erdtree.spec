%define debug_package %{nil}

Name:           erdtree
Version:        3.1.2
Release:        1%{?dist}
Summary:        Modern tree command with file sizes

License:        MIT
URL:            https://github.com/solidiquis/erdtree
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
A modern, multi-threaded file-tree visualizer and disk usage analyzer.

%prep
%setup -q -n erdtree-3.1.2

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/erd %{buildroot}%{_bindir}/erd

%files
%{_bindir}/erd

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 3.1.2-1
- Initial custom RPM build
