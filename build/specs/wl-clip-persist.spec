%define debug_package %{nil}

Name:           wl-clip-persist
Version:        0.5.0
Release:        1%{?dist}
Summary:        Keep Wayland clipboard content after source app closes

License:        MIT
URL:            https://github.com/Linus789/wl-clip-persist
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
wl-clip-persist keeps Wayland clipboard content from disappearing after the
source application closes. Uses ext-data-control-v1 or wlr-data-control
protocols.

%prep
%setup -q -n wl-clip-persist-%{version}

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/wl-clip-persist %{buildroot}%{_bindir}/wl-clip-persist

%files
%{_bindir}/wl-clip-persist

%changelog
* Sun Feb 09 2026 neg-serg <neg-serg@example.com> - 0.5.0-1
- Initial custom RPM build
