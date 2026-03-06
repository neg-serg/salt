{% from '_imports.jinja' import user, home, gopass_secret %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_service.jinja' import ensure_dir, user_service_restart %}
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _proxypilot_api_key = gopass_secret('api/proxypilot-local', "awk '/^api-keys:/{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _proxypilot_mgmt_key = gopass_secret('api/proxypilot-management', "awk '/^[[:space:]]*secret-key:[[:space:]]*/{sub(/^[[:space:]]*secret-key:[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _codex_api_key = _proxypilot_api_key %}

{{ ensure_dir('opencode_config_dir', home ~ '/.config/opencode') }}
opencode_config:
  file.recurse:
    - name: {{ home }}/.config/opencode
    - source: salt://dotfiles/dot_config/opencode
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
{{ ensure_dir('proxypilot_config_dir', home ~ '/.config/proxypilot') }}
proxypilot_config:
  file.managed:
    - name: {{ home }}/.config/proxypilot/config.yaml
    - source: salt://configs/proxypilot.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        user: {{ user }}
        home: {{ home }}
        api_key: {{ _proxypilot_api_key | tojson }}
        mgmt_key: {{ _proxypilot_mgmt_key | tojson }}
    - require:
      - file: proxypilot_config_dir
{{ ensure_dir('codex_config_dir', home ~ '/.codex') }}
codex_config:
  file.recurse:
    - name: {{ home }}/.codex
    - source: salt://dotfiles/dot_codex
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
    - require:
      - file: codex_config_dir

# Keep Codex auth in Salt state; value is resolved from gopass at apply time.
codex_auth:
  file.managed:
    - name: {{ home }}/.codex/auth.json
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - contents: |
        {"auth_mode":"apikey","OPENAI_API_KEY":{{ _codex_api_key | tojson }}}
    - require:
      - file: codex_config

{{ user_service_restart('restart_proxypilot_on_config_change', 'proxypilot.service', onlyif='systemctl --user is-active proxypilot.service >/dev/null 2>&1', onchanges=['file: proxypilot_config']) }}

{{ npm_pkg('codex', pkg='@openai/codex') }}
