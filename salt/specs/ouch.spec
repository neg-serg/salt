%define debug_package %{nil}

Name:           ouch
Version:        0.6.1
Release:        1%{?dist}
Summary:        Compress/decompress with auto-detection

License:        MIT
URL:            https://github.com/ouch-org/ouch
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  gcc-c++
BuildRequires:  clang
BuildRequires:  clang-devel
BuildRequires:  git

%description
A CLI tool for compressing and decompressing files with auto-detection of formats.

%prep
%setup -q -n ouch-0.6.1

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/ouch %{buildroot}%{_bindir}/ouch

%files
%{_bindir}/ouch

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.6.1-1
- Initial custom RPM build
