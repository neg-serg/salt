%define debug_package %{nil}

Name:           newsraft
Version:        0.26
Release:        1%{?dist}
Summary:        Feed reader for terminal

License:        ISC
URL:            https://codeberg.org/newsraft/newsraft
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  ncurses-devel
BuildRequires:  libcurl-devel
BuildRequires:  yajl-devel
BuildRequires:  gumbo-parser-devel
BuildRequires:  sqlite-devel
BuildRequires:  expat-devel
BuildRequires:  scdoc

%description
Feed reader for terminal with a snappy TUI. Supports Atom and RSS feeds.

%prep
%setup -q -n newsraft-%{version}

%build
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot} PREFIX=/usr

%files
%{_bindir}/newsraft
%{_mandir}/man1/newsraft.1*
%{_datadir}/newsraft/

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 0.26-1
- Initial custom RPM build
