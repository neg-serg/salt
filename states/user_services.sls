{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import user_service_file, user_unit_override, user_service_enable %}
{% import_yaml 'data/user_services.yaml' as us %}
# Systemd user services: mail, calendar, chezmoi, media, surfingkeys

{% set svc = host.features.user_services %}

# Unit IDs and service names gated by feature flags
{% set mail_unit_ids = ['mbsync_gmail_service', 'mbsync_gmail_timer', 'imapnotify_gmail_service'] %}
{% set vdirsyncer_unit_ids = ['vdirsyncer_service', 'vdirsyncer_timer'] %}
{% set mail_enable = ['imapnotify-gmail.service'] %}
{% set mail_timers = ['mbsync-gmail.timer'] %}
{% set vdirsyncer_timers = ['vdirsyncer.timer'] %}

# --- Systemd user services for media ---
# Drop-in override for mpDris2.service: adds MPD ordering
{% set mpdris2_override %}
[Unit]
After=mpd.service
Wants=mpd.service

[Service]
Restart=always
RestartSec=3
{% endset %}
{{ user_unit_override('mpdris2_user_service', 'mpDris2.service', contents=mpdris2_override) }}

chezmoi_config:
  file.managed:
    - name: {{ home }}/.config/chezmoi/chezmoi.toml
    - source: salt://dotfiles/dot_config/chezmoi/chezmoi.toml
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: True

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
      - file: chezmoi_config

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
{%- set skip =
    (unit.id in mail_unit_ids and not svc.mail) or
    (unit.id in vdirsyncer_unit_ids and not svc.vdirsyncer)
-%}
{% if not skip %}
{{ user_service_file(unit.id, unit.filename) }}
{%- do _unit_reqs.append('file: ' ~ unit.id) -%}
{% endif %}
{% endfor %}

# --- Filter enable lists based on feature flags ---
{%- set filtered_services = [] -%}
{%- for name in us.enable_services -%}
{%- if not (name in mail_enable and not svc.mail) -%}
{%- do filtered_services.append(name) -%}
{%- endif -%}
{%- endfor -%}

{%- set filtered_timers = [] -%}
{%- for name in us.enable_now_timers -%}
{%- if not ((name in mail_timers and not svc.mail) or
            (name in vdirsyncer_timers and not svc.vdirsyncer)) -%}
{%- do filtered_timers.append(name) -%}
{%- endif -%}
{%- endfor -%}

# --- Enable user services: single daemon-reload + batch enable ---
{{ user_service_enable('enable_user_services', filtered_services, start_now=filtered_timers, daemon_reload=True, requires=_unit_reqs) }}

# --- Disable services for disabled features ---
{% if not svc.mail %}
disable_mail_services:
  cmd.run:
    - name: systemctl --user disable --now mbsync-gmail.timer imapnotify-gmail.service 2>/dev/null; true
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - onlyif: systemctl --user is-enabled mbsync-gmail.timer 2>/dev/null
{% endif %}

{% if not svc.vdirsyncer %}
disable_vdirsyncer_services:
  cmd.run:
    - name: systemctl --user disable --now vdirsyncer.timer 2>/dev/null; true
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - onlyif: systemctl --user is-enabled vdirsyncer.timer 2>/dev/null
{% endif %}
