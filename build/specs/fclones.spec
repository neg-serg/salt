%define debug_package %{nil}

Name:           fclones
Version:        0.35.0
Release:        1%{?dist}
Summary:        Fast duplicate file finder

License:        MIT
URL:            https://github.com/pkolaczk/fclones
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
Efficient duplicate file finder and remover with multiple output formats.

%prep
%setup -q -n fclones-0.35.0

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/fclones %{buildroot}%{_bindir}/fclones

%files
%{_bindir}/fclones

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.35.0-1
- Initial custom RPM build
