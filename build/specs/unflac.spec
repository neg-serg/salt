%define debug_package %{nil}

Name:           unflac
Version:        1.4
Release:        1%{?dist}
Summary:        FLAC cuesheet splitter

License:        MIT
URL:            https://git.sr.ht/~ft/unflac
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang
BuildRequires:  git

Requires:       ffmpeg

%description
Command line tool for fast, frame-accurate audio image + cue sheet splitting.
Requires ffmpeg/ffprobe at runtime.

%prep
%setup -q -n unflac-%{version}

%build
go build -ldflags="-s -w" -o unflac .

%install
mkdir -p %{buildroot}%{_bindir}
install -m 0755 unflac %{buildroot}%{_bindir}/unflac

%files
%{_bindir}/unflac

%changelog
* Mon Feb 10 2026 neg-serg <neg-serg@example.com> - 1.4-1
- Initial custom RPM build
