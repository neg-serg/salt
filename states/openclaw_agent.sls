{% from '_imports.jinja' import user, home, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir, user_service_file, user_service_enable, user_service_restart %}
{% import_yaml 'data/versions.yaml' as ver %}

# ── Secret resolution (gopass primary, config-file fallback) ─────────
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}

{% set _gopass_proxy = salt['cmd.run_all']('gopass show -o api/proxypilot-local 2>/dev/null', runas=user, python_shell=True, ignore_retcode=True) %}
{% if _gopass_proxy.get('retcode', 1) == 0 %}
{% set _proxy_key = _gopass_proxy['stdout'].strip() %}
{% else %}
{% set _proxy_key = salt['cmd.run_stdout']("awk '/^api-keys:/{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true", runas=user).strip() %}
{% endif %}

{% set _gopass_tg = salt['cmd.run_all']('gopass show -o api/openclaw-telegram 2>/dev/null', runas=user, python_shell=True, ignore_retcode=True) %}
{% set _telegram_token = _gopass_tg['stdout'].strip() if _gopass_tg.get('retcode', 1) == 0 else '' %}

# ── Install OpenClaw via npm (version-pinned) ────────────────────────
# Inline cmd.run instead of npm_pkg macro: needs --prefix and version guard
openclaw_npm:
  cmd.run:
    - name: npm install -g --prefix {{ home }}/.local openclaw@{{ ver.openclaw }}
    - runas: {{ user }}
    - unless: openclaw --version 2>/dev/null | rg -q '{{ ver.openclaw }}'
    - parallel: True
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

# ── Config + credentials directories ─────────────────────────────────
{{ ensure_dir('openclaw_config_dir', home ~ '/.openclaw', mode='0700') }}
{{ ensure_dir('openclaw_credentials_dir', home ~ '/.openclaw/credentials', mode='0700') }}

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
        proxy_key: {{ _proxy_key | tojson }}
        telegram_token: {{ _telegram_token | tojson }}
    - require:
      - file: openclaw_config_dir

# ── Lingering (user services survive logout) ─────────────────────────
openclaw_lingering:
  cmd.run:
    - name: loginctl enable-linger {{ user }}
    - unless: loginctl show-user {{ user }} 2>/dev/null | rg -q '^Linger=yes'

# ── Systemd user service ─────────────────────────────────────────────
{{ user_service_file('openclaw_service', 'openclaw-gateway.service') }}

{{ user_service_enable('openclaw_enabled', start_now=['openclaw-gateway.service'], requires=['cmd: openclaw_npm', 'file: openclaw_config', 'file: openclaw_service']) }}

{{ user_service_restart('restart_openclaw_on_config_change', 'openclaw-gateway.service', onlyif='systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1', onchanges=['file: openclaw_config']) }}
