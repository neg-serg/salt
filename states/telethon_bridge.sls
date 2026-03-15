{% from '_imports.jinja' import host, user, home, gopass_secret %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, user_service_file, user_service_enable %}
{% import_yaml 'data/versions.yaml' as ver %}
# ── Secret resolution (gopass primary, credentials-file fallback) ─────
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _proxy_key = gopass_secret('api/proxypilot-local', "awk '/^api-keys:/{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _creds = home ~ '/.telethon-bridge/credentials' %}
{% set _api_id = gopass_secret('api/telegram-telethon-id', "cat " ~ _creds ~ "/api-id 2>/dev/null || true") %}
{% set _api_hash = gopass_secret('api/telegram-telethon-hash', "cat " ~ _creds ~ "/api-hash 2>/dev/null || true") %}

# Reuse OpenClaw Telegram UIDs for allowlist
{% set _telegram_uid = gopass_secret('api/openclaw-telegram-uid', "cat " ~ home ~ "/.openclaw/credentials/telegram-uid 2>/dev/null || true") %}
{% set _telegram_uid_levra = '6931112349' %}
{% set _telegram_uid_guest2 = '7379049772' %}

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

# ── Lingering (user services survive logout) ─────────────────────────
telethon_bridge_lingering:
  cmd.run:
    - name: loginctl enable-linger {{ user }}
    - unless: loginctl show-user {{ user }} 2>/dev/null | rg -q '^Linger=yes'

# ── Systemd user service ─────────────────────────────────────────────
{{ user_service_file('telethon_bridge_service', 'telethon-bridge.service') }}

{{ user_service_enable('telethon_bridge_enabled', start_now=['telethon-bridge.service'], requires=['cmd: install_python_telethon', 'file: telethon_bridge_config', 'file: telethon_bridge_script', 'file: telethon_bridge_service']) }}
