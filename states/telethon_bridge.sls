{% from '_imports.jinja' import user, home, proxypilot_key, tg_secret %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, user_service_enable, user_service_file %}
{% import_yaml 'data/versions.yaml' as ver %}
# ── Secret resolution ─────────────────────────────────────────────────
{% set _proxy_key = proxypilot_key() %}
{% set _tb_creds = home ~ '/.telethon-bridge/credentials' %}
{% set _api_id = tg_secret('api/telegram-telethon-id', 'api-id', cred_base=_tb_creds) %}
{% set _api_hash = tg_secret('api/telegram-telethon-hash', 'api-hash', cred_base=_tb_creds) %}
{% set _telegram_uid = tg_secret('api/openclaw-telegram-uid', 'telegram-uid') %}
{% set _telegram_uid_levra = tg_secret('api/telegram-uid-levra', 'telegram-uid-levra') %}
{% set _telegram_uid_guest2 = tg_secret('api/telegram-uid-guest2', 'telegram-uid-guest2') %}

# ── Install python-telethon from AUR ─────────────────────────────────
{{ paru_install('python_telethon', 'python-telethon', version=ver.telethon) }}

# ── Directories ──────────────────────────────────────────────────────
{{ ensure_dir('telethon_bridge_dir', home ~ '/.telethon-bridge') }}
{{ ensure_dir('telethon_bridge_credentials_dir', home ~ '/.telethon-bridge/credentials', mode='0700') }}
{{ ensure_dir('telethon_bridge_media_dir', home ~ '/.telethon-bridge/media') }}

# ── Deploy config (secrets injected at apply time) ────────────────────
telethon_bridge_config:
  file.managed:
    - name: {{ home }}/.telethon-bridge/config.yaml
    - source: salt://configs/telethon-bridge.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        home: {{ home }}
        api_id: {{ _api_id | tojson }}
        api_hash: {{ _api_hash | tojson }}
        proxy_key: {{ _proxy_key | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
        telegram_uid_levra: {{ _telegram_uid_levra | tojson }}
        telegram_uid_guest2: {{ _telegram_uid_guest2 | tojson }}
    - require:
      - file: telethon_bridge_dir

# ── Deploy bridge script ─────────────────────────────────────────────
telethon_bridge_script:
  file.managed:
    - name: {{ home }}/.local/bin/telethon-bridge
    - source: salt://scripts/telethon-bridge.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

# ── Deploy init script ──────────────────────────────────────────────
telethon_bridge_init_script:
  file.managed:
    - name: {{ home }}/.local/bin/telethon-bridge-init
    - source: salt://scripts/telethon-bridge-init.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - file: telethon_bridge_config

# ── Systemd user service ─────────────────────────────────────────────
{{ user_service_file('telethon_bridge_service', 'telethon-bridge.service') }}

{{ user_service_enable('telethon_bridge_enabled', start_now=['telethon-bridge.service'], requires=['cmd: install_python_telethon', 'file: telethon_bridge_config', 'file: telethon_bridge_script', 'file: telethon_bridge_service']) }}
