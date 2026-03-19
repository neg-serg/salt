{% from '_imports.jinja' import user, home, gopass_secret, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir, user_service_file, user_service_enable, user_service_restart, user_linger %}
{% from '_macros_install.jinja' import npm_build_workflow %}
{% import_yaml 'data/versions.yaml' as ver %}

# ── Secret resolution (gopass primary, credential-file fallback) ─────
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _proxy_key = gopass_secret('api/proxypilot-local', "awk '/^api-keys:/{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _telegram_token = gopass_secret('api/openclaw-telegram', "cat " ~ home ~ "/.openclaw/credentials/telegram-token 2>/dev/null || true") %}
{% set _telegram_uid = gopass_secret('api/openclaw-telegram-uid', "cat " ~ home ~ "/.openclaw/credentials/telegram-uid 2>/dev/null || true") %}

{% set _nanoclaw_dir = home ~ '/.local/share/nanoclaw' %}
{% set _nanoclaw_config = home ~ '/.config/nanoclaw' %}

# ── Clone NanoClaw repo ──────────────────────────────────────────────
nanoclaw_clone:
  cmd.run:
    - name: git clone --depth=1 https://github.com/qwibitai/nanoclaw.git {{ _nanoclaw_dir }}
    - runas: {{ user }}
    - creates: {{ _nanoclaw_dir }}/package.json
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

# ── npm install + build + version pin ─────────────────────────────────
{{ npm_build_workflow('nanoclaw', dir=_nanoclaw_dir, version=ver.nanoclaw, require=['cmd: nanoclaw_clone']) }}

# ── Config directories ───────────────────────────────────────────────
{{ ensure_dir('nanoclaw_config_dir', _nanoclaw_config) }}
{{ ensure_dir('nanoclaw_store_dir', _nanoclaw_dir ~ '/store') }}
{{ ensure_dir('nanoclaw_data_dir', _nanoclaw_dir ~ '/data') }}
{{ ensure_dir('nanoclaw_groups_dir', _nanoclaw_dir ~ '/groups') }}

# ── .env (secrets injected at apply time) ─────────────────────────────
# NanoClaw reads .env from its working directory (process.cwd()).
# ANTHROPIC_BASE_URL points to ProxyPilot so all traffic goes through it.
nanoclaw_env:
  file.managed:
    - name: {{ _nanoclaw_dir }}/.env
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        # NanoClaw environment — managed by Salt (initial seed only)
        ANTHROPIC_API_KEY={{ _proxy_key }}
        ANTHROPIC_BASE_URL=http://127.0.0.1:8317
        ASSISTANT_NAME=NanoClaw
        CONTAINER_IMAGE=nanoclaw-agent:latest
        TZ=Europe/Moscow
{%- if _telegram_token %}
        TELEGRAM_BOT_TOKEN={{ _telegram_token }}
{%- endif %}
    - require:
      - cmd: nanoclaw_clone

# ── Sender allowlist ──────────────────────────────────────────────────
nanoclaw_sender_allowlist:
  file.managed:
    - name: {{ _nanoclaw_config }}/sender-allowlist.json
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        {
          "mode": "allowlist",
          "logDenied": true,
          "groups": {
            "*": {
              "allowed": [{{ _telegram_uid | tojson }}]
            }
          }
        }
    - require:
      - file: nanoclaw_config_dir

# ── Mount allowlist (container filesystem mounts) ─────────────────────
nanoclaw_mount_allowlist:
  file.managed:
    - name: {{ _nanoclaw_config }}/mount-allowlist.json
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        {
          "allowedMounts": []
        }
    - require:
      - file: nanoclaw_config_dir

# ── Lingering (user services survive logout) ──────────────────────────
{{ user_linger('nanoclaw_lingering') }}

# ── Systemd user service ──────────────────────────────────────────────
{{ user_service_file('nanoclaw_service', 'nanoclaw.service') }}

{{ user_service_enable('nanoclaw_enabled', start_now=['nanoclaw.service'], requires=['cmd: nanoclaw_version', 'file: nanoclaw_env', 'file: nanoclaw_service', 'file: nanoclaw_sender_allowlist']) }}

{{ user_service_restart('restart_nanoclaw_on_env_change', 'nanoclaw.service', onlyif='systemctl --user is-active nanoclaw.service >/dev/null 2>&1', onchanges=['file: nanoclaw_env']) }}
