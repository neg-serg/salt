%define debug_package %{nil}

Name:           wallust
Version:        3.3.0
Release:        1%{?dist}
Summary:        Generate colorschemes from images

License:        MIT
URL:            https://codeberg.org/explosion-mental/wallust
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
wallust generates colorschemes from images. It is a successor to pywal/wpgtk
with support for multiple backends and color manipulation.

%prep
%setup -q -n wallust-%{version}

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/wallust %{buildroot}%{_bindir}/wallust

%files
%{_bindir}/wallust

%changelog
* Sat Feb 08 2026 neg-serg <neg-serg@example.com> - 3.3.0-1
- Initial custom RPM build
