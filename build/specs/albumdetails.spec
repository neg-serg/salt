Name:           albumdetails
Version:        0.1
Release:        1%{?dist}
Summary:        Generate details for music album
License:        MIT
URL:            https://github.com/neg-serg/albumdetails
Source0:        albumdetails-master.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  taglib-devel

%description
CLI tool to extract and display music album metadata (artist, album,
genre, year, bitrate, duration, track listing) from audio files using TagLib.

%prep
%autosetup -n albumdetails-master

%build
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot} PREFIX=/usr

%files
%license LICENSE
%{_bindir}/albumdetails
