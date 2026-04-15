{% from '_imports.jinja' import user, home, retry_attempts, retry_interval, proxypilot_key, tg_secret %}
{% from '_macros_service.jinja' import ensure_dir, container_service, user_service_restart %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% import_yaml 'data/versions.yaml' as ver %}

# ── Secret resolution ─────────────────────────────────────────────────
{% set _proxy_key = proxypilot_key() %}
{% set _telegram_token = tg_secret('api/nanoclaw-telegram', 'telegram-token') %}
{% set _telegram_uid = tg_secret('api/nanoclaw-telegram-uid', 'telegram-uid') %}

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
{% from '_macros_install.jinja' import npm_build_workflow %}
{{ npm_build_workflow('nanoclaw', dir=_nanoclaw_dir, version=ver.nanoclaw, require=['cmd: nanoclaw_clone']) }}

# ── Config directories ───────────────────────────────────────────────
{{ ensure_dir('nanoclaw_config_dir', _nanoclaw_config) }}
{{ ensure_dir('nanoclaw_store_dir', _nanoclaw_dir ~ '/store') }}
{{ ensure_dir('nanoclaw_data_dir', _nanoclaw_dir ~ '/data') }}
{{ ensure_dir('nanoclaw_groups_dir', _nanoclaw_dir ~ '/groups') }}

# ── .env (secrets injected at apply time) ─────────────────────────────
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

# ── In-place cutover: remove native user unit ──
nanoclaw_native_unit_absent:
  file.absent:
    - name: {{ home }}/.config/systemd/user/nanoclaw.service

nanoclaw_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - onchanges:
      - file: nanoclaw_native_unit_absent

# ── Container deployment ──
{{ container_service('nanoclaw', catalog.nanoclaw, image_registry,
    user_scope=True,
    requires=['cmd: nanoclaw_version', 'file: nanoclaw_env', 'file: nanoclaw_sender_allowlist', 'file: nanoclaw_mount_allowlist', 'cmd: nanoclaw_native_unit_daemon_reload']) }}

# ── Restart on env change ──
{{ user_service_restart('restart_nanoclaw_on_env_change', 'nanoclaw.service',
    onlyif='systemctl --user is-active nanoclaw.service >/dev/null 2>&1',
    onchanges=['file: nanoclaw_env']) }}
