{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import user_service_disable, user_service_enable, user_service_file, user_unit_override %}
{% import_yaml 'data/user_services.yaml' as us %}
# Systemd user services: mail, calendar, chezmoi, media, surfingkeys

{% set svc = host.features.user_services %}
{% set feature_enabled = {'mail': svc.mail, 'vdirsyncer': svc.vdirsyncer} %}

{% macro feature_entry_enabled(entry) -%}
{%- set features = entry.get('features', []) -%}
{%- if not features -%}
True
{%- else -%}
{%- set ns = namespace(enabled=True) -%}
{%- for feature in features -%}
{%- if not feature_enabled.get(feature, False) -%}
{%- set ns.enabled = False -%}
{%- endif -%}
{%- endfor -%}
{{ ns.enabled }}
{%- endif -%}
{%- endmacro %}

# --- Systemd user services for media ---
# Drop-in override for mpDris2.service: adds MPD ordering
# Gated on mpd feature — mpd.sls is conditionally included
{% if host.features.mpd %}
{% set mpdris2_override %}
[Unit]
After=mpd.service
Wants=mpd.service

[Service]
Restart=always
RestartSec=3
{% endset %}
{{ user_unit_override('mpdris2_user_service', 'mpDris2.service', contents=mpdris2_override) }}
{% endif %}

chezmoi_source_symlink:
  file.symlink:
    - name: {{ home }}/.local/share/chezmoi
    - target: {{ home }}/src/salt/dotfiles
    - user: {{ user }}
    - group: {{ user }}
    - force: True
    - makedirs: True
    - require:
      - user: user_neg

# --- Mail directories (needed by mbsync) ---
{% if svc.mail %}
mail_directories:
  file.directory:
    - names:
      - {{ home }}/.local/mail/gmail/INBOX
      - {{ home }}/.local/mail/gmail/[Gmail]/Sent Mail
      - {{ home }}/.local/mail/gmail/[Gmail]/Drafts
      - {{ home }}/.local/mail/gmail/[Gmail]/All Mail
      - {{ home }}/.local/mail/gmail/[Gmail]/Trash
      - {{ home }}/.local/mail/gmail/[Gmail]/Spam
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
{% endif %}

# --- Systemd user services (unit files in units/user/) ---
{%- set _unit_reqs = [] -%}
{% for unit in us.unit_files %}
{% if feature_entry_enabled(unit) == 'True' %}
{{ user_service_file(unit.id, unit.filename) }}
{%- do _unit_reqs.append('file: ' ~ unit.id) -%}
{%- do _unit_reqs.append('cmd: ' ~ unit.id ~ '_daemon_reload') -%}
{% endif %}
{% endfor %}

# --- Filter enable lists based on feature flags ---
{%- set filtered_services = [] -%}
{%- for entry in us.enable_services -%}
{%- if feature_entry_enabled(entry) == 'True' -%}
{%- do filtered_services.append(entry.name) -%}
{%- endif -%}
{%- endfor -%}

{%- set filtered_timers = [] -%}
{%- for entry in us.enable_now_timers -%}
{%- if feature_entry_enabled(entry) == 'True' -%}
{%- do filtered_timers.append(entry.name) -%}
{%- endif -%}
{%- endfor -%}

# --- Enable user services: single daemon-reload + batch enable ---
{{ user_service_enable('enable_user_services', filtered_services, start_now=filtered_timers, requires=_unit_reqs) }}

# --- Disable network mount services (rclone) — require explicit mount ---
{{ user_service_disable('disable_rclone_services', ['rclone-gdrive.service', 'rclone-yadisk.service']) }}

# --- Disable services for disabled features ---
{%- set _all_feature_units = us.enable_services + us.enable_now_timers -%}
{%- for feature_name, is_enabled in feature_enabled.items() -%}
{%- if not is_enabled -%}
{%- set disabled_units = [] -%}
{%- for entry in _all_feature_units -%}
{%- if feature_name in entry.get('features', []) -%}
{%- do disabled_units.append(entry.name) -%}
{%- endif -%}
{%- endfor -%}
{%- if disabled_units %}
{{ user_service_disable('disable_' ~ feature_name ~ '_services', disabled_units) }}
{%- endif -%}
{%- endif -%}
{%- endfor -%}
