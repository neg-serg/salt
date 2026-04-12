{% from '_imports.jinja' import home, user %}
{% from '_macros_install.jinja' import git_clone_deploy %}
{% import_yaml 'data/installers_themes.yaml' as themes %}
# Theme and icon installers (data-driven from data/installers_themes.yaml)

{% for name, cfg in themes.git_clone_deploy.items() %}
{{ git_clone_deploy(name, cfg.repo, cfg.dest, cfg.get('items'), creates=(home ~ cfg.creates) if cfg.get('creates') else None, user=user, home=home) }}

{% endfor %}

vicinae_theme:
  file.managed:
    - name: {{ home }}/.local/share/vicinae/themes/flight-dark.toml
    - source: salt://configs/vicinae/flight-dark.toml
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

# Alkano-aio cursor theme (original source dead, mirror: github.com/neg-serg/Alkano-aio)
alkano_aio_cursor:
  cmd.run:
    - name: |
        set -eo pipefail
        _td=$(mktemp -d)
        trap 'rm -rf "$_td"' EXIT
        git clone --depth=1 https://github.com/neg-serg/Alkano-aio.git "$_td/alkano"
        sudo mkdir -p /usr/share/icons/Alkano-aio
        sudo cp -r "$_td/alkano/Alkano-aio"/* /usr/share/icons/Alkano-aio/
        sudo chmod 755 /usr/share/icons/Alkano-aio
        sudo chmod 755 /usr/share/icons/Alkano-aio/cursors
        sudo find /usr/share/icons/Alkano-aio/cursors -type f -exec chmod 644 {} +
    - creates: /usr/share/icons/Alkano-aio/cursor.theme
    - parallel: True
    - retry:
        attempts: 3
        interval: 5
