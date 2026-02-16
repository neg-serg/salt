# Salt state to build and install custom Iosevka Nerd Font from PKGBUILD
# Builds Iosevka with custom glyph variants, then patches with Nerd Font icons
{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import pkgbuild_install %}
{% set user = host.user %}

{{ pkgbuild_install('iosevka-neg-fonts', 'salt://build/pkgbuilds/iosevka-neg-fonts', user=user, timeout=7200) }}
