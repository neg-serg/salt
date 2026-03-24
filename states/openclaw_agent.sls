{% from '_imports.jinja' import host, user, home, gopass_secret %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_service.jinja' import ensure_dir, user_linger, user_service_enable, user_service_file, user_service_restart, user_unit_override %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/openclaw_models.yaml' as allowed_models %}
# ── Secret resolution (gopass primary, credentials-file fallback) ─────
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _proxy_key = gopass_secret('api/proxypilot-local', "awk '/^api-keys:/{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _creds = home ~ '/.openclaw/credentials' %}
{% set _telegram_token = gopass_secret('api/openclaw-telegram', "cat " ~ _creds ~ "/telegram-token 2>/dev/null || true") %}
{% set _telegram_uid = gopass_secret('api/openclaw-telegram-uid', "cat " ~ _creds ~ "/telegram-uid 2>/dev/null || true") %}
{% set _telegram_uid_levra = gopass_secret('api/telegram-uid-levra', "cat " ~ _creds ~ "/telegram-uid-levra 2>/dev/null || true") %}
{% set _telegram_uid_guest2 = gopass_secret('api/telegram-uid-guest2', "cat " ~ _creds ~ "/telegram-uid-guest2 2>/dev/null || true") %}
{% set _groq_key = gopass_secret('api/groq', "true") %}

# ── Install OpenClaw via npm (version-pinned) ────────────────────────
{{ npm_pkg('openclaw', pkg='openclaw@' ~ ver.openclaw, version=ver.openclaw) }}

# ── Config + credentials directories ─────────────────────────────────
{{ ensure_dir('openclaw_config_dir', home ~ '/.openclaw') }}
{{ ensure_dir('openclaw_credentials_dir', home ~ '/.openclaw/credentials', mode='0700') }}

# ── Config migration marker directory ─────────────────────────────────
{% set _migrate_dir = home ~ '/.openclaw/.migrations' %}
{{ ensure_dir('openclaw_migrate_dir', _migrate_dir) }}

# ── One-shot config migrations ────────────────────────────────────────
# Each migration deletes the config so file.managed (replace: False)
# reseeds from the updated template. A marker file prevents re-runs,
# because OpenClaw rewrites its own config at startup and strips fields
# that grep-based guards relied on (allowFrom, bindings, etc.).

{% set migrations = [
  ('openclaw_config_migrate',     'proxypilot'),
  ('openclaw_dualagent_migrate',  'dualagent'),
  ('openclaw_guest_user_migrate', 'guest-levra'),
  ('openclaw_guest2_migrate',     'guest2'),
  ('openclaw_groq_stt_migrate',   'groq-stt'),
  ('openclaw_groq_models_migrate','groq-models'),
  ('openclaw_telegram_reseed',    'telegram-reseed'),
  ('openclaw_telegram_creds',     'telegram-creds'),
] %}

{% for state_id, marker in migrations %}
{{ state_id }}:
  cmd.run:
    - name: rm -f {{ home }}/.openclaw/openclaw.json && touch {{ _migrate_dir }}/{{ marker }}
    - creates: {{ _migrate_dir }}/{{ marker }}
    - onlyif: test -f {{ home }}/.openclaw/openclaw.json
    - require:
      - file: openclaw_config_dir
      - file: openclaw_migrate_dir
      {%- if not loop.first %}
      - cmd: {{ migrations[loop.index0 - 1][0] }}
      {%- endif %}
{% endfor %}

# ── Deploy config (secrets injected at apply time) ───────────────────
# replace: False — OpenClaw rewrites its config at startup (adds defaults,
# metadata, reorders keys). Salt deploys the initial seed only;
# to force re-deploy, delete ~/.openclaw/openclaw.json first.
openclaw_config:
  file.managed:
    - name: {{ home }}/.openclaw/openclaw.json
    - source: salt://configs/openclaw.json.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - context:
        home: {{ home }}
        proxy_key: {{ _proxy_key | tojson }}
        telegram_token: {{ _telegram_token | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
        telegram_uid_levra: {{ _telegram_uid_levra | tojson }}
        telegram_uid_guest2: {{ _telegram_uid_guest2 | tojson }}
        groq_key: {{ _groq_key | tojson }}
    - require:
      - file: openclaw_config_dir
      - cmd: openclaw_telegram_creds

# ── Config sanitizer (ExecStartPre) ─────────────────────────────────
# Two-layer model filter run before every gateway start:
#   Layer 1: strips models with contextWindow/maxTokens <= 0 (STT leaks)
#   Layer 2: strips models not on the per-provider allowlist
# Allowlist sourced from data/openclaw_models.yaml, embedded at apply time.
openclaw_sanitize_script:
  file.managed:
    - name: {{ home }}/.local/bin/openclaw-sanitize-config
    - source: salt://scripts/openclaw-sanitize-config.py.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - context:
        allowed_models: {{ allowed_models | tojson }}
    - require:
      - file: openclaw_config_dir

# ── Lingering (user services survive logout) ─────────────────────────
{{ user_linger('openclaw_lingering') }}

# ── Systemd user service ─────────────────────────────────────────────
{{ user_service_file('openclaw_service', 'openclaw-gateway.service') }}

# Drop-in: pass Wayland display env vars so mpv and other GUI tools work
{% set openclaw_wayland_override %}
[Service]
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR={{ host.runtime_dir }}
{% endset %}
{{ user_unit_override('openclaw_wayland_env', 'openclaw-gateway.service', contents=openclaw_wayland_override) }}

{{ user_service_enable('openclaw_enabled', start_now=['openclaw-gateway.service'], requires=['cmd: install_openclaw', 'file: openclaw_config', 'file: openclaw_service', 'file: openclaw_wayland_env', 'file: openclaw_sanitize_script']) }}

{{ user_service_restart('restart_openclaw_on_config_change', 'openclaw-gateway.service', onlyif='systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1', onchanges=['file: openclaw_config']) }}
