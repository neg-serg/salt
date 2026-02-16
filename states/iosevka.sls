# Salt state to build and install custom Iosevka Nerd Font from PKGBUILD
# Builds Iosevka with custom glyph variants, then patches with Nerd Font icons
{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set build_dir = '/tmp/pkgbuild/iosevka-neg-fonts' %}

iosevka_pkgbuild:
  file.recurse:
    - name: {{ build_dir }}
    - source: salt://build/pkgbuilds/iosevka-neg-fonts
    - makedirs: True
    - user: {{ user }}
    - group: {{ user }}

build_iosevka:
  cmd.run:
    - name: |
        set -eo pipefail
        su - {{ user }} -c 'cd {{ build_dir }} && makepkg -sf --noconfirm'
        pacman -U --noconfirm --needed {{ build_dir }}/*.pkg.tar.zst
        rm -rf {{ build_dir }}
    - shell: /bin/bash
    - timeout: 7200
    - unless: pacman -Q iosevka-neg-fonts
    - require:
      - file: iosevka_pkgbuild
