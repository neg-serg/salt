%define debug_package %{nil}

Name:           zk
Version:        0.15.2
Release:        1%{?dist}
Summary:        Zettelkasten note CLI

License:        GPL-3.0-or-later
URL:            https://github.com/zk-org/zk
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  gcc
BuildRequires:  git

%description
A plain text note-taking assistant following the Zettelkasten method.

%prep
%setup -q -n zk-0.15.2

%build
CGO_ENABLED=1 go build -buildvcs=false -tags "fts5" -ldflags="-s -w -X=main.Version=%{version}" -o zk .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 zk %{buildroot}%{_bindir}/zk

%files
%{_bindir}/zk

%changelog
* Fri Feb 06 2026 neg-serg <neg-serg@example.com> - 0.15.2-1
- Initial custom RPM build
