{% from '_imports.jinja' import host, user, home %}
{% from '_macros_install.jinja' import git_clone_deploy %}
# Theme and icon installers

# --- matugen themes (matugen itself now in pacman) ---
{{ git_clone_deploy('matugen-themes', 'https://github.com/InioX/matugen-themes.git', '~/.config/matugen/templates', ['*/'], user=user, home=home) }}

# --- Kora icon theme ---
{{ git_clone_deploy('kora-icons', 'https://github.com/bikass/kora.git', '~/.local/share/icons', ['kora', 'kora-light', 'kora-light-panel', 'kora-pgrey'], creates=home ~ '/.local/share/icons/kora', user=user, home=home) }}

# --- Flight GTK theme (dark + light) ---
{{ git_clone_deploy('flight-gtk', 'https://github.com/neg-serg/Flight-Plasma-Themes.git', '~/.local/share/themes', ['Flight-Dark-GTK', 'Flight-light-GTK'], creates=home ~ '/.local/share/themes/Flight-Dark-GTK', user=user, home=home) }}
