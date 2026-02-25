# All font installs: pacman, AUR, downloaded, custom PKGBUILD builds
# Run: sudo salt-call --local state.apply fonts
{% from '_imports.jinja' import user, home %}
{% from '_macros_pkg.jinja' import pacman_install, paru_install, pkgbuild_install %}
{% from '_macros_install.jinja' import download_font_zip %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/fonts.yaml' as fonts %}

# ===================================================================
# Pacman fonts
# ===================================================================

{% for name, pkg in fonts.pacman.items() %}
{{ pacman_install(name, pkg) }}
{% endfor %}

# ===================================================================
# AUR fonts
# ===================================================================

{% for name, pkg in fonts.paru.items() %}
{{ paru_install(name, pkg) }}
{% endfor %}

# ===================================================================
# PKGBUILD fonts (custom builds)
# ===================================================================

# Iosevka with custom glyph variants, patched with Nerd Font icons
{{ pkgbuild_install('iosevka-neg-fonts', 'salt://build/pkgbuilds/iosevka-neg-fonts', user=user, timeout=7200) }}

# ===================================================================
# Downloaded fonts (not in repos)
# ===================================================================

{% for name, opts in fonts.download_zip.items() %}
{% set _v = ver.get(name, '') %}
{% set url = opts.url | replace('${VER}', _v) %}
{{ download_font_zip(name, url, opts.subdir, hash=opts.get('hash'), version=_v if _v else None, user=user, home=home) }}
{% endfor %}
