{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_service.jinja' import ensure_dir %}

{%- macro user_file_recurse(state_id, path, source) -%}
{{ state_id }}:
  file.recurse:
    - name: {{ path }}
    - source: {{ source }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
{%- endmacro -%}

{{ ensure_dir('opencode_config_dir', home ~ '/.config/opencode') }}

{{ user_file_recurse('opencode_config', home ~ '/.config/opencode', 'salt://dotfiles/dot_config/opencode') }}

{{ ensure_dir('proxypilot_config_dir', home ~ '/.config/proxypilot', mode='0700') }}

proxypilot_config:
  file.managed:
    - name: {{ home }}/.config/proxypilot/config.yaml
    - source: salt://dotfiles/dot_config/proxypilot/config.yaml.tmpl
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - makedirs: True

{{ ensure_dir('codex_config_dir', home ~ '/.codex', mode='0700') }}

{{ user_file_recurse('codex_config', home ~ '/.codex', 'salt://dotfiles/dot_codex') }}

# Keep Codex auth in Salt state; value is resolved from gopass at apply time.
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
    # systemctl --user requires explicit user bus env in non-interactive Salt runs.
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - onchanges:
      - file: proxypilot_config

{{ npm_pkg('codex', pkg='@openai/codex') }}
