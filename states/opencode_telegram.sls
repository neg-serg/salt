{% from '_imports.jinja' import user, home, tg_secret %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_install.jinja' import curl_bin %}
{% from '_macros_service.jinja' import ensure_dir, user_service_enable, user_service_file %}
{% import_yaml 'data/versions.yaml' as ver %}

# ── Secret resolution ─────────────────────────────────────────────────
{% set _telegram_token_otb = tg_secret('api/opencode-telegram-bot', 'telegram-token', cred_base=home ~ '/.config/opencode-telegram-bot/credentials') %}
{% set _telegram_token_tc = tg_secret('api/telecode-telegram', 'telegram-token', cred_base=home ~ '/.telecode/credentials') %}
{% set _telegram_uid = tg_secret('api/openclaw-telegram-uid', 'telegram-uid') %}

# Guards: deploy configs and enable services only when tokens are available.
# Without tokens the binaries are still installed but services stay disabled.
{% set _has_otb_token = _telegram_token_otb | length > 0 %}
{% set _has_tc_token = _telegram_token_tc | length > 0 %}

# ══════════════════════════════════════════════════════════════════════
# 1. OpenCode Telegram Bot (npm, requires opencode serve)
# ══════════════════════════════════════════════════════════════════════

{{ npm_pkg('opencode_telegram', pkg='@grinev/opencode-telegram-bot', bin='opencode-telegram') }}

# ── Config directory + credentials fallback ────────────────────────────
{{ ensure_dir('opencode_telegram_bot_config_dir', home ~ '/.config/opencode-telegram-bot') }}
{{ ensure_dir('opencode_telegram_bot_credentials_dir', home ~ '/.config/opencode-telegram-bot/credentials', mode='0700') }}

{% if _has_otb_token %}
opencode_telegram_bot_env:
  file.managed:
    - name: {{ home }}/.config/opencode-telegram-bot/.env
    - source: salt://configs/opencode-telegram-bot.env.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        telegram_token: {{ _telegram_token_otb | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
    - require:
      - file: opencode_telegram_bot_config_dir
{% endif %}

# ── OpenCode serve (API server for the bot) ────────────────────────────
{{ user_service_file('opencode_serve_service', 'opencode-serve.service') }}

{{ user_service_enable('opencode_serve_enabled',
    start_now=['opencode-serve.service'],
    onlyif='command -v opencode',
    requires=['file: opencode_serve_service']) }}

# ── Bot systemd service ───────────────────────────────────────────────
{{ user_service_file('opencode_telegram_bot_service', 'opencode-telegram-bot.service') }}

{% if _has_otb_token %}
{{ user_service_enable('opencode_telegram_bot_enabled',
    start_now=['opencode-telegram-bot.service'],
    onlyif='test -s ' ~ home ~ '/.config/opencode-telegram-bot/.env',
    requires=['cmd: install_opencode_telegram', 'file: opencode_telegram_bot_env', 'file: opencode_telegram_bot_service', 'file: opencode_serve_service']) }}
{% endif %}

# ══════════════════════════════════════════════════════════════════════
# 2. Telecode (Go binary, spawns CLI directly)
# ══════════════════════════════════════════════════════════════════════

{{ curl_bin('telecode',
    'https://github.com/futureCreator/telecode/releases/download/v' ~ ver.telecode ~ '/telecode-linux-amd64',
    version=ver.telecode) }}

# ── Config directory + credentials fallback ────────────────────────────
{{ ensure_dir('telecode_config_dir', home ~ '/.telecode') }}
{{ ensure_dir('telecode_credentials_dir', home ~ '/.telecode/credentials', mode='0700') }}

{% if _has_tc_token %}
telecode_config:
  file.managed:
    - name: {{ home }}/.telecode/config.yml
    - source: salt://configs/telecode.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        home: {{ home }}
        bot_token: {{ _telegram_token_tc | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
    - require:
      - file: telecode_config_dir
{% endif %}

# ── Systemd service ──────────────────────────────────────────────────
{{ user_service_file('telecode_service', 'telecode.service') }}

{% if _has_tc_token %}
{{ user_service_enable('telecode_enabled',
    start_now=['telecode.service'],
    onlyif='test -s ' ~ home ~ '/.telecode/config.yml',
    requires=['cmd: install_telecode', 'file: telecode_config', 'file: telecode_service']) }}
{% endif %}
