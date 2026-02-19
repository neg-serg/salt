{% from '_imports.jinja' import host, user, home %}
{% from '_macros_install.jinja' import github_tar, git_clone_deploy %}
{% import_yaml 'data/versions.yaml' as ver %}
# Theme and icon installers

# --- matugen (Material You color generation) ---
{{ github_tar('matugen', 'https://github.com/InioX/matugen/releases/download/v' ~ ver.matugen ~ '/matugen-' ~ ver.matugen ~ '-x86_64.tar.gz', user=user, home=home) }}
{{ git_clone_deploy('matugen-themes', 'https://github.com/InioX/matugen-themes.git', '~/.config/matugen/templates', ['*/'], user=user, home=home) }}

# --- Kora icon theme ---
{{ git_clone_deploy('kora-icons', 'https://github.com/bikass/kora.git', '~/.local/share/icons', ['kora', 'kora-light', 'kora-light-panel', 'kora-pgrey'], creates=home ~ '/.local/share/icons/kora', user=user, home=home) }}

# --- Flight GTK theme (dark + light) ---
{{ git_clone_deploy('flight-gtk', 'https://github.com/neg-serg/Flight-Plasma-Themes.git', '~/.local/share/themes', ['Flight-Dark-GTK', 'Flight-light-GTK'], creates=home ~ '/.local/share/themes/Flight-Dark-GTK', user=user, home=home) }}
