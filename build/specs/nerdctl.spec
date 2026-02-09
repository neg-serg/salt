%define debug_package %{nil}

Name:           nerdctl
Version:        2.2.1
Release:        1%{?dist}
Summary:        containerd CLI

License:        Apache-2.0
URL:            https://github.com/containerd/nerdctl
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

%description
Docker-compatible CLI for containerd with rootless container support.

%prep
%setup -q -n nerdctl-%{version}

%build
CGO_ENABLED=0 go build -ldflags "-X github.com/containerd/nerdctl/v2/pkg/version.Version=%{version}" -o nerdctl ./cmd/nerdctl

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 nerdctl %{buildroot}%{_bindir}/nerdctl

%files
%{_bindir}/nerdctl

%changelog
* Fri Feb 07 2026 neg-serg <neg-serg@example.com> - 2.2.1-1
- Initial custom RPM build
