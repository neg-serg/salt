# All font installs: pacman, downloaded, custom PKGBUILD builds
# Run: sudo salt-call --local state.apply fonts
{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import pacman_install, pkgbuild_install, download_font_zip %}
{% import_yaml 'data/versions.yaml' as ver %}
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
{{ download_font_zip('fira_code_nerd', 'https://github.com/ryanoasis/nerd-fonts/releases/download/v' ~ ver.firacode_nerd ~ '/FiraCode.zip', 'FiraCodeNerd', user=user, home=home) }}

# --- oldschool PC fonts (bitmap-style OTF) ---
{{ download_font_zip('oldschool_pc_fonts', 'https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v' ~ ver.oldschool_pc_fonts ~ '_linux.zip', 'oldschool-pc', user=user, home=home) }}

# --- Hyprlock theme fonts (downloaded from font.download) ---
{{ download_font_zip('sf_pro_display', 'https://font.download/dl/font/sf-pro-display.zip', 'SFProDisplay', user=user, home=home) }}
{{ download_font_zip('anurati', 'https://font.download/dl/font/anurati.zip', 'Anurati', user=user, home=home) }}
{{ download_font_zip('alfa_slab_one', 'https://font.download/dl/font/alfa-slab-one.zip', 'AlfaSlabOne', user=user, home=home) }}
