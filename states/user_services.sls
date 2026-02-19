{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import user_service_file, user_unit_override, user_service_enable %}
{% import_yaml 'data/user_services.yaml' as us %}
# Systemd user services: mail, calendar, chezmoi, media, surfingkeys

# --- Systemd user services for media ---
# Drop-in override for mpDris2.service: adds MPD ordering
{% set mpdris2_override %}
[Unit]
After=mpd.service
Wants=mpd.service
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

# --- Systemd user services (unit files in units/user/) ---
{% for unit in us.unit_files %}
{{ user_service_file(unit.id, unit.filename) }}
{% endfor %}

# --- Enable user services: single daemon-reload + batch enable ---
{%- set _unit_reqs = [] -%}
{%- for u in us.unit_files -%}
{%- do _unit_reqs.append('file: ' ~ u.id) -%}
{%- endfor -%}
{{ user_service_enable('enable_user_services', us.enable_services, start_now=us.enable_now_timers, daemon_reload=True, requires=_unit_reqs) }}
