{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval %}
{% from '_macros_pkg.jinja' import npm_pkg %}
# OpenCode AI coding agent: TUI config + neg custom theme
# Codex CLI (OpenAI): routed through ProxyPilot

opencode_config:
  file.recurse:
    - name: {{ home }}/.config/opencode
    - source: salt://dotfiles/dot_config/opencode
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

proxypilot_config:
  file.managed:
    - name: {{ home }}/.config/proxypilot/config.yaml
    - source: salt://dotfiles/dot_config/proxypilot/config.yaml.tmpl
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - makedirs: True

codex_config:
  file.recurse:
    - name: {{ home }}/.codex
    - source: salt://dotfiles/dot_codex
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

# Auth key stored in gopass, written to ~/.codex/auth.json
codex_auth:
  file.managed:
    - name: {{ home }}/.codex/auth.json
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - contents: |
        {"auth_mode":"apikey","OPENAI_API_KEY":"{{ salt['cmd.run']('gopass show -o api/proxypilot-local') }}"}
    - require:
      - file: codex_config

restart_proxypilot_on_config_change:
  cmd.run:
    - name: systemctl --user restart proxypilot.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - onchanges:
      - file: proxypilot_config

{{ npm_pkg('codex', pkg='@openai/codex') }}
