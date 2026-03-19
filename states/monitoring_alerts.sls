{% from '_imports.jinja' import host, user, home, gopass_secret %}
{% from '_macros_service.jinja' import ensure_dir, user_service_enable, user_service_file %}
{% import_yaml 'data/monitored_services.yaml' as monitored %}
{% if host.features.monitoring.alerts %}

# ── Secret resolution (gopass primary, credentials-file fallback) ─────
{% set _creds = home ~ '/.openclaw/credentials' %}
{% set _telegram_token = gopass_secret('api/openclaw-telegram', "cat " ~ _creds ~ "/telegram-token 2>/dev/null || true") %}
{% set _telegram_uid = gopass_secret('api/openclaw-telegram-uid', "cat " ~ _creds ~ "/telegram-uid 2>/dev/null || true") %}

# ── Directories ──────────────────────────────────────────────────────
{{ ensure_dir('salt_monitor_cache_dir', home ~ '/.cache/salt-monitor', mode='0755') }}
{{ ensure_dir('salt_monitor_alerts_dir', home ~ '/.cache/salt-monitor/alerts', mode='0755') }}

# ── Cleanup: remove old monitoring scripts and units ─────────────────
{% set old_files = [
    home ~ '/.local/bin/openclaw-health-check',
    home ~ '/.config/systemd/user/openclaw-health.service',
    home ~ '/.config/systemd/user/openclaw-health.timer',
] %}

{% for old_file in old_files %}
old_monitoring_{{ loop.index }}:
  file.absent:
    - name: {{ old_file }}
{% endfor %}

# ── Deploy salt-alert script ─────────────────────────────────────────
salt_alert_script:
  file.managed:
    - name: {{ home }}/.local/bin/salt-alert
    - source: salt://scripts/salt-alert
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - context:
        telegram_token: {{ _telegram_token | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
        desktop_notifications: {{ monitored.settings.desktop_notifications | default(true) }}
    - require:
      - file: salt_monitor_cache_dir

# ── Deploy salt-monitor script ───────────────────────────────────────
salt_monitor_script:
  file.managed:
    - name: {{ home }}/.local/bin/salt-monitor
    - source: salt://scripts/salt-monitor
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - context:
        telegram_token: {{ _telegram_token | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
        monitored: {{ monitored | tojson }}
    - require:
      - file: salt_alert_script

# ── Systemd user units ──────────────────────────────────────────────
{{ user_service_file('salt_monitor_service', 'salt-monitor.service') }}
{{ user_service_file('salt_monitor_watchdog_service', 'salt-monitor-watchdog.service') }}
{{ user_service_file('salt_monitor_watchdog_timer', 'salt-monitor-watchdog.timer') }}

# ── Enable services ─────────────────────────────────────────────────
{{ user_service_enable('salt_monitor_enabled',
    start_now=['salt-monitor.service', 'salt-monitor-watchdog.timer'],
    requires=['file: salt_monitor_script', 'file: salt_alert_script',
              'file: salt_monitor_service', 'file: salt_monitor_watchdog_service',
              'file: salt_monitor_watchdog_timer']) }}

# ── Loki alert rules (conditional on Loki being enabled) ─────────────
{% if host.features.monitoring.loki %}
loki_alert_rules:
  file.managed:
    - name: /var/lib/loki/rules/salt-monitor-rules.yaml
    - source: salt://configs/loki-alert-rules.yaml.j2
    - template: jinja
    - user: loki
    - group: loki
    - mode: '0644'
    - makedirs: True
{% endif %}

{% endif %}
