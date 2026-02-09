%define debug_package %{nil}

Name:           htmlq
Version:        0.4.0
Release:        1%{?dist}
Summary:        jq for HTML - extract content using CSS selectors

License:        MIT
URL:            https://github.com/mgdm/htmlq
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  rust
BuildRequires:  cargo
BuildRequires:  git

%description
Like jq, but for HTML. Uses CSS selectors to extract pieces of content from HTML files.

%prep
%setup -q -n htmlq-0.4.0

%build
cargo build --release

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/htmlq %{buildroot}%{_bindir}/htmlq

%files
%{_bindir}/htmlq

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.4.0-1
- Initial custom RPM build
