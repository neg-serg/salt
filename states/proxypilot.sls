{% from '_imports.jinja' import user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, container_service, user_service_restart %}
{% import_yaml 'data/free_providers.yaml' as free_providers_data %}

# ProxyPilot LLM proxy — pure Quadlet (Podman container).
# Replaces native pacman package (proxypilot) + user systemd service.

{# ── Secret resolution (same logic as opencode.sls) ── #}
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _pp_raw = salt['cmd.run_stdout']('cat ' ~ _proxypilot_cfg ~ ' 2>/dev/null || true', runas=user, python_shell=True).strip() %}
{% set _pp = (_pp_raw | load_yaml) if _pp_raw else {} %}
{% set _existing_mgmt = _pp.get('remote-management', {}).get('secret-key', '') %}

{% set _gopass_ok = salt['cmd.retcode']('gopass show -o api/proxypilot-local 2>/dev/null', runas=user, python_shell=True, ignore_retcode=True) == 0 %}
{% if _gopass_ok %}
{% set _proxypilot_api_key = salt['cmd.run_stdout']('gopass show -o api/proxypilot-local', runas=user).strip() %}
{% set _proxypilot_mgmt_key = _existing_mgmt if _existing_mgmt else salt['cmd.run_stdout']('gopass show -o api/proxypilot-management', runas=user).strip() %}
{% set _free_providers = [] %}
{% for p in free_providers_data.get('providers', []) %}
  {% if p.gopass_key is defined %}
    {% set _key = salt['cmd.run_stdout']('gopass show -o ' ~ p.gopass_key, runas=user).strip() %}
  {% else %}
    {% set _key = p.get('dummy_key', '') %}
  {% endif %}
  {% if _key %}
    {% do _free_providers.append({'name': p.name, 'base_url': p.base_url, 'api_key': _key, 'models': p.models}) %}
  {% endif %}
{% endfor %}
{% else %}
{% set _proxypilot_api_key = _pp.get('api-keys', [''])[0] %}
{% set _proxypilot_mgmt_key = _existing_mgmt %}
{% set _provider_keys = {} %}
{% for entry in _pp.get('openai-compatibility', []) %}
  {% set _entry_keys = entry.get('api-key-entries', []) %}
  {% if _entry_keys %}
    {% do _provider_keys.update({entry.get('name', ''): _entry_keys[0].get('api-key', '')}) %}
  {% endif %}
{% endfor %}
{% set _free_providers = [] %}
{% for p in free_providers_data.get('providers', []) %}
  {% if p.gopass_key is defined %}
    {% set _key = _provider_keys.get(p.name, '') %}
  {% else %}
    {% set _key = p.get('dummy_key', '') %}
  {% endif %}
  {% if _key %}
    {% do _free_providers.append({'name': p.name, 'base_url': p.base_url, 'api_key': _key, 'models': p.models}) %}
  {% endif %}
{% endfor %}
{% endif %}

{# ── Config directory + config file ── #}
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

{# ── In-place cutover: remove native user unit ── #}
proxypilot_native_unit_absent:
  file.absent:
    - name: {{ home }}/.config/systemd/user/proxypilot.service

proxypilot_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - onchanges:
      - file: proxypilot_native_unit_absent

{# ── Container deployment ── #}
{{ container_service('proxypilot', catalog.proxypilot, image_registry,
    user_scope=True,
    requires=['file: proxypilot_config', 'cmd: proxypilot_native_unit_daemon_reload']) }}

{# ── Restart on config change ── #}
{{ user_service_restart('restart_proxypilot_on_config_change', 'proxypilot.service',
    onlyif='systemctl --user is-active proxypilot.service >/dev/null 2>&1',
    onchanges=['file: proxypilot_config']) }}
