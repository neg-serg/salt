# Install fonts referenced by dotfiles (rofi, hyprlock, quickshell, mpv)
# Run: sudo salt-call --local state.apply fonts

{% from '_macros.jinja' import pacman_install %}

{% from 'host_config.jinja' import host %}
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
# Downloaded fonts (not in repos)
# ===================================================================

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
