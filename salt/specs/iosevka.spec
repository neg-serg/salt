Name:           iosevka-neg-fonts
Version:        34.1.0
Release:        1%{?dist}
Summary:        Custom Iosevka Nerd Fonts by neg-serg

License:        OFL-1.1
URL:            https://github.com/be5invis/Iosevka
Source0:        iosevka-source-%{version}.tar.gz
Source1:        iosevka-neg.toml

BuildRequires:  npm
BuildRequires:  git
BuildRequires:  ttfautohint
BuildRequires:  python3-pip
BuildRequires:  python3-wheel
BuildRequires:  python3-setuptools
BuildRequires:  python3-fonttools # dependency of nerd-font-patcher

%description
This package provides a custom build of the Iosevka typeface,
specifically tailored by neg-serg, and patched with Nerd Font glyphs.

%prep
%setup -q -n iosevka-source-%{version}
cp %{SOURCE1} private-build-plans.toml

%build
# Build Iosevka
npm install
npm run build -- contents::Iosevkaneg

# Install nerd-font-patcher
pip3 install nerd-font-patcher

# Create directory for built TTF files
mkdir -p %{_builddir}/iosevka-build/ttf
cp -v dist/Iosevkaneg/TTF/*.ttf %{_builddir}/iosevka-build/ttf/

# Patch with Nerd Font
mkdir -p %{_builddir}/iosevka-build/nerd-fonts
# Use find to get all generated TTF files
find %{_builddir}/iosevka-build/ttf -name "*.ttf" -print0 | xargs -0 -n 1 nerd-font-patcher \
    --complete --quiet --outputdir %{_builddir}/iosevka-build/nerd-fonts

%install
# Install the patched fonts
mkdir -p %{buildroot}%{_datadir}/fonts/truetype/iosevka-neg
install -m 0644 %{_builddir}/iosevka-build/nerd-fonts/*.ttf %{buildroot}%{_datadir}/fonts/truetype/iosevka-neg/

%files
%{_datadir}/fonts/truetype/iosevka-neg/

%changelog
* %{__date} neg-serg <neg-serg@example.com> - 34.1.0-1
- Initial custom Iosevka Nerd Font RPM build