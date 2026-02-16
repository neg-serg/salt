{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import github_tar, git_clone_deploy %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set user = host.user %}
{% set home = host.home %}
# Theme and icon installers

# --- matugen (Material You color generation) ---
{{ github_tar('matugen', 'https://github.com/InioX/matugen/releases/download/v' ~ ver.matugen ~ '/matugen-' ~ ver.matugen ~ '-x86_64.tar.gz') }}
{{ git_clone_deploy('matugen-themes', 'https://github.com/InioX/matugen-themes.git', '~/.config/matugen/templates', ['*/']) }}

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
{{ git_clone_deploy('flight-gtk', 'https://github.com/neg-serg/Flight-Plasma-Themes.git', '~/.local/share/themes', ['Flight-Dark-GTK', 'Flight-light-GTK'], creates=home ~ '/.local/share/themes/Flight-Dark-GTK') }}
