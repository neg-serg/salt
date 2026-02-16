# All font installs: pacman, downloaded, custom PKGBUILD builds
# Run: sudo salt-call --local state.apply fonts
{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import pacman_install, pkgbuild_install, download_font_zip %}
{% set user = host.user %}
{% set home = host.home %}
{% set fonts_dir = home ~ '/.local/share/fonts' %}
{% set firacode_ver = '3.3.0' %}
{% set oldschool_pc_ver = '2.2' %}

# ===================================================================
# Pacman fonts
# ===================================================================

{{ pacman_install('jetbrains-mono-nerd', 'ttf-jetbrains-mono-nerd') }}
{{ pacman_install('icomoon-feather',     'ttf-icomoon-feather') }}
{{ pacman_install('font-awesome',        'otf-font-awesome') }}
{{ pacman_install('noto-fonts',          'noto-fonts') }}
{{ pacman_install('noto-fonts-emoji',    'noto-fonts-emoji') }}
{{ pacman_install('ibm-plex',            'ttf-ibm-plex') }}
{{ pacman_install('inter-font',          'inter-font') }}

# ===================================================================
# PKGBUILD fonts (custom builds)
# ===================================================================

# Iosevka with custom glyph variants, patched with Nerd Font icons
{{ pkgbuild_install('iosevka-neg-fonts', 'salt://build/pkgbuilds/iosevka-neg-fonts', user=user, timeout=7200) }}

# ===================================================================
# Downloaded fonts (not in repos)
# ===================================================================

# --- FiraCode Nerd Font ---
{{ fonts_dir }}/FiraCodeNerd:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

download_fira_code_nerd:
  cmd.run:
    - name: |
        curl -L -o /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v{{ firacode_ver }}/FiraCode.zip
        unzip -o /tmp/FiraCode.zip -d {{ fonts_dir }}/FiraCodeNerd
        rm /tmp/FiraCode.zip
        fc-cache -f
    - runas: {{ user }}
    - unless: "ls {{ fonts_dir }}/FiraCodeNerd/FiraCodeNerdFontMono-Regular.ttf"
    - require:
      - file: {{ fonts_dir }}/FiraCodeNerd

# --- oldschool PC fonts (bitmap-style OTF) ---
install_oldschool_pc_fonts:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p {{ fonts_dir }}/oldschool-pc
        curl -fsSL https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v{{ oldschool_pc_ver }}_linux.zip -o /tmp/fonts.zip
        unzip -o /tmp/fonts.zip -d /tmp/oldschool-fonts
        find /tmp/oldschool-fonts -name '*.otf' -exec cp {} {{ fonts_dir }}/oldschool-pc/ \;
        fc-cache -f {{ fonts_dir }}/oldschool-pc/
        rm -rf /tmp/fonts.zip /tmp/oldschool-fonts
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ fonts_dir }}/oldschool-pc

# --- Hyprlock theme fonts (downloaded from font.download) ---
{{ download_font_zip('sf_pro_display', 'https://font.download/dl/font/sf-pro-display.zip', 'SFProDisplay', user=user, home=home) }}
{{ download_font_zip('anurati', 'https://font.download/dl/font/anurati.zip', 'Anurati', user=user, home=home) }}
{{ download_font_zip('alfa_slab_one', 'https://font.download/dl/font/alfa-slab-one.zip', 'AlfaSlabOne', user=user, home=home) }}
