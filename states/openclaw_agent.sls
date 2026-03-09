{% from '_imports.jinja' import host, user, home, gopass_secret %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% from '_macros_service.jinja' import ensure_dir, user_service_file, user_service_enable, user_service_restart %}
{% import_yaml 'data/versions.yaml' as ver %}
{% if host.features.openclaw %}

# ── Secret resolution (gopass primary, config-file fallback) ─────────
{% set _proxypilot_cfg = home ~ '/.config/proxypilot/config.yaml' %}
{% set _proxy_key = gopass_secret('api/proxypilot-local', "awk '/^api-keys:/{getline; sub(/^[[:space:]]*-[[:space:]]*\"?/, \"\"); sub(/\"?[[:space:]]*$/, \"\"); print; exit}' " ~ _proxypilot_cfg ~ " 2>/dev/null || true") %}
{% set _openclaw_cfg = home ~ '/.openclaw/openclaw.json' %}
{% set _telegram_token = gopass_secret('api/openclaw-telegram', "python3 -c \"import json; print(json.load(open('" ~ _openclaw_cfg ~ "')).get('channels',{}).get('telegram',{}).get('botToken',''))\" 2>/dev/null || true") %}
{% set _telegram_uid = gopass_secret('api/openclaw-telegram-uid', "python3 -c \"import json; print(json.load(open('" ~ _openclaw_cfg ~ "')).get('channels',{}).get('telegram',{}).get('allowFrom',[''])[0])\" 2>/dev/null || true") %}
{% set _telegram_uid_levra = 'REDACTED_UID_LEVRA' %}

# ── Install OpenClaw via npm (version-pinned) ────────────────────────
{{ npm_pkg('openclaw', pkg='openclaw@' ~ ver.openclaw, version=ver.openclaw) }}

# ── Config + credentials directories ─────────────────────────────────
{{ ensure_dir('openclaw_config_dir', home ~ '/.openclaw') }}
{{ ensure_dir('openclaw_credentials_dir', home ~ '/.openclaw/credentials', mode='0700') }}

# ── Migrate old Anthropic-only config to ProxyPilot ───────────────────
# One-shot: delete existing config if it still has the old Anthropic provider,
# so file.managed (replace: False) will reseed from the updated template.
openclaw_config_migrate:
  cmd.run:
    - name: rm -f {{ home }}/.openclaw/openclaw.json
    - onlyif: test -f {{ home }}/.openclaw/openclaw.json
    - unless: grep -q 'openai-completions' {{ home }}/.openclaw/openclaw.json
    - require:
      - file: openclaw_config_dir

# ── Migrate single-agent config to dual-agent ────────────────────────
# One-shot: delete config if it lacks the "agents.list" key (dual-agent
# structure), so file.managed (replace: False) will reseed from the
# updated template with owner + guest agents.
openclaw_dualagent_migrate:
  cmd.run:
    - name: rm -f {{ home }}/.openclaw/openclaw.json
    - onlyif: test -f {{ home }}/.openclaw/openclaw.json
    - unless: grep -q '"guest"' {{ home }}/.openclaw/openclaw.json
    - require:
      - file: openclaw_config_dir
      - cmd: openclaw_config_migrate

# ── Migrate to add guest user binding ─────────────────────────────────
# One-shot: delete config if it lacks the LevRa72 binding,
# so file.managed (replace: False) will reseed with updated allowFrom + bindings.
openclaw_guest_user_migrate:
  cmd.run:
    - name: rm -f {{ home }}/.openclaw/openclaw.json
    - onlyif: test -f {{ home }}/.openclaw/openclaw.json
    - unless: grep -q '{{ _telegram_uid_levra }}' {{ home }}/.openclaw/openclaw.json
    - require:
      - file: openclaw_config_dir
      - cmd: openclaw_dualagent_migrate

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
        telegram_uid: {{ _telegram_uid | tojson }}
        telegram_uid_levra: {{ _telegram_uid_levra | tojson }}
    - require:
      - file: openclaw_config_dir
      - cmd: openclaw_config_migrate
      - cmd: openclaw_dualagent_migrate
      - cmd: openclaw_guest_user_migrate

# ── Lingering (user services survive logout) ─────────────────────────
openclaw_lingering:
  cmd.run:
    - name: loginctl enable-linger {{ user }}
    - unless: loginctl show-user {{ user }} 2>/dev/null | rg -q '^Linger=yes'

# ── Systemd user service ─────────────────────────────────────────────
{{ user_service_file('openclaw_service', 'openclaw-gateway.service') }}

{{ user_service_enable('openclaw_enabled', start_now=['openclaw-gateway.service'], requires=['cmd: install_openclaw', 'file: openclaw_config', 'file: openclaw_service']) }}

{{ user_service_restart('restart_openclaw_on_config_change', 'openclaw-gateway.service', onlyif='systemctl --user is-active openclaw-gateway.service >/dev/null 2>&1', onchanges=['file: openclaw_config']) }}

# ── Health check script ──────────────────────────────────────────────
openclaw_health_script:
  file.managed:
    - name: {{ home }}/.local/bin/openclaw-health-check
    - source: salt://scripts/openclaw-health-check.sh
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - context:
        telegram_token: {{ _telegram_token | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}

# ── Health check systemd units ───────────────────────────────────────
{{ user_service_file('openclaw_health_service', 'openclaw-health.service') }}
{{ user_service_file('openclaw_health_timer', 'openclaw-health.timer') }}

{{ user_service_enable('openclaw_health_enabled',
    start_now=['openclaw-health.timer'],
    requires=['file: openclaw_health_script', 'file: openclaw_health_service', 'file: openclaw_health_timer']) }}

{% endif %}
