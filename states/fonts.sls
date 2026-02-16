# All font installs: pacman, downloaded, custom PKGBUILD builds
# Run: sudo salt-call --local state.apply fonts
{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import pacman_install, pkgbuild_install %}
{% set user = host.user %}
{% set home = host.home %}
{% set fonts_dir = home ~ '/.local/share/fonts' %}

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
        curl -L -o /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip
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
        curl -fsSL https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_linux.zip -o /tmp/fonts.zip
        unzip -o /tmp/fonts.zip -d /tmp/oldschool-fonts
        find /tmp/oldschool-fonts -name '*.otf' -exec cp {} {{ fonts_dir }}/oldschool-pc/ \;
        fc-cache -f {{ fonts_dir }}/oldschool-pc/
        rm -rf /tmp/fonts.zip /tmp/oldschool-fonts
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ fonts_dir }}/oldschool-pc

# --- SF Pro Display (Apple) — hyprlock SF_Pro / Arfan_on_Clouds themes ---
{{ fonts_dir }}/SFProDisplay:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

install_sf_pro_display:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL 'https://font.download/dl/font/sf-pro-display.zip' -o /tmp/sf-pro-display.zip
        unzip -o /tmp/sf-pro-display.zip -d {{ fonts_dir }}/SFProDisplay
        fc-cache -f {{ fonts_dir }}/SFProDisplay
        rm -f /tmp/sf-pro-display.zip
    - runas: {{ user }}
    - shell: /bin/bash
    - unless: "ls {{ fonts_dir }}/SFProDisplay/*.otf 2>/dev/null || ls {{ fonts_dir }}/SFProDisplay/*.ttf 2>/dev/null"
    - require:
      - file: {{ fonts_dir }}/SFProDisplay

# --- Anurati — hyprlock Anurati theme ---
{{ fonts_dir }}/Anurati:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

install_anurati:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL 'https://font.download/dl/font/anurati.zip' -o /tmp/anurati.zip
        unzip -o /tmp/anurati.zip -d {{ fonts_dir }}/Anurati
        fc-cache -f {{ fonts_dir }}/Anurati
        rm -f /tmp/anurati.zip
    - runas: {{ user }}
    - shell: /bin/bash
    - unless: "ls {{ fonts_dir }}/Anurati/*.otf 2>/dev/null || ls {{ fonts_dir }}/Anurati/*.ttf 2>/dev/null"
    - require:
      - file: {{ fonts_dir }}/Anurati

# --- Alfa Slab One — hyprlock Arfan_on_Clouds theme ---
{{ fonts_dir }}/AlfaSlabOne:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

install_alfa_slab_one:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL 'https://font.download/dl/font/alfa-slab-one.zip' -o /tmp/alfa-slab-one.zip
        unzip -o /tmp/alfa-slab-one.zip -d {{ fonts_dir }}/AlfaSlabOne
        fc-cache -f {{ fonts_dir }}/AlfaSlabOne
        rm -f /tmp/alfa-slab-one.zip
    - runas: {{ user }}
    - shell: /bin/bash
    - unless: "ls {{ fonts_dir }}/AlfaSlabOne/*.otf 2>/dev/null || ls {{ fonts_dir }}/AlfaSlabOne/*.ttf 2>/dev/null"
    - require:
      - file: {{ fonts_dir }}/AlfaSlabOne
