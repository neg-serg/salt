{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import github_tar %}
{% set user = host.user %}
{% set home = host.home %}
# Theme, icon, and font installers

# --- oldschool PC fonts (bitmap-style OTF) ---
install_oldschool_pc_fonts:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/share/fonts/oldschool-pc
        curl -fsSL https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_linux.zip -o /tmp/fonts.zip
        unzip -o /tmp/fonts.zip -d /tmp/oldschool-fonts
        find /tmp/oldschool-fonts -name '*.otf' -exec cp {} ~/.local/share/fonts/oldschool-pc/ \;
        fc-cache -f ~/.local/share/fonts/oldschool-pc/
        rm -rf /tmp/fonts.zip /tmp/oldschool-fonts
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/share/fonts/oldschool-pc

# --- matugen (Material You color generation) ---
{{ github_tar('matugen', 'https://github.com/InioX/matugen/releases/download/v3.1.0/matugen-3.1.0-x86_64.tar.gz') }}

install_matugen_themes:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/InioX/matugen-themes.git /tmp/matugen-themes
        mkdir -p ~/.config/matugen/templates
        cp -r /tmp/matugen-themes/*/ ~/.config/matugen/templates/
        rm -rf /tmp/matugen-themes
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.config/matugen/templates

# --- Kora icon theme ---
install_kora_icons:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSIL -o /dev/null -w '%{url_effective}' https://github.com/bikass/kora/releases/latest | grep -oP '[^/]+$')
        curl -fsSL "https://github.com/bikass/kora/archive/refs/tags/${TAG}.tar.gz" -o /tmp/kora.tar.gz
        tar -xzf /tmp/kora.tar.gz -C /tmp
        mkdir -p ~/.local/share/icons
        cp -r /tmp/kora-*/kora ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light-panel ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-pgrey ~/.local/share/icons/
        gtk-update-icon-cache ~/.local/share/icons/kora 2>/dev/null || true
        rm -rf /tmp/kora.tar.gz /tmp/kora-*
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/share/icons/kora

# --- Flight GTK theme (dark + light) ---
install_flight_gtk_theme:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/neg-serg/Flight-Plasma-Themes.git /tmp/flight-gtk
        mkdir -p ~/.local/share/themes
        cp -r /tmp/flight-gtk/Flight-Dark-GTK ~/.local/share/themes/
        cp -r /tmp/flight-gtk/Flight-light-GTK ~/.local/share/themes/
        rm -rf /tmp/flight-gtk
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/share/themes/Flight-Dark-GTK
