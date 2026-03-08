{% from '_imports.jinja' import host, user, home, gopass_secret %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_service.jinja' import ensure_dir, user_service_restart %}
{% import_yaml 'data/free_providers.yaml' as free_providers_data %}
{% if host.features.opencode %}
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _proxypilot_api_key = gopass_secret('api/proxypilot-local', "awk '/^api-keys:/{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _proxypilot_mgmt_key = gopass_secret('api/proxypilot-management', "awk '/^[[:space:]]*secret-key:[[:space:]]*/{sub(/^[[:space:]]*secret-key:[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _codex_api_key = _proxypilot_api_key %}

{# Resolve free fallback provider API keys from gopass (emergency-only providers).
   gopass fails in Salt daemon context (no GPG agent); AWK parses the existing
   rendered config as fallback.  First deploy: run scripts/bootstrap-free-providers.sh
   to seed the config, then subsequent `just` runs maintain keys via AWK. #}
{% set _free_providers = [] %}
{% for p in free_providers_data.get('providers', []) %}
  {% if p.gopass_key is defined %}
    {% set _awk_fallback = "awk '/name: \"" ~ p.name ~ "\"/{f=1} f && /api-key:/{gsub(/.*api-key:[[:space:]]*\"?/,\"\"); gsub(/\"[[:space:]]*$/,\"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true" %}
    {% set _key = gopass_secret(p.gopass_key, _awk_fallback) %}
  {% else %}
    {% set _key = p.get('dummy_key', '') %}
  {% endif %}
  {% if _key %}
    {% do _free_providers.append({'name': p.name, 'base_url': p.base_url, 'api_key': _key, 'models': p.models}) %}
  {% endif %}
{% endfor %}

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
        free_providers: {{ _free_providers | tojson }}
    - require:
      - file: proxypilot_config_dir
{{ ensure_dir('codex_config_dir', home ~ '/.codex') }}

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
      - file: codex_config_dir

{{ user_service_restart('restart_proxypilot_on_config_change', 'proxypilot.service', onlyif='systemctl --user is-active proxypilot.service >/dev/null 2>&1', onchanges=['file: proxypilot_config']) }}

{{ npm_pkg('codex', pkg='@openai/codex') }}
{% endif %}
