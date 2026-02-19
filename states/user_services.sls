{% from 'host_config.jinja' import host %}
{% from '_macros_service.jinja' import user_service_file %}
{% import_yaml 'data/user_services.yaml' as us %}
{% set user = host.user %}
{% set home = host.home %}
# Systemd user services: mail, calendar, chezmoi, media, surfingkeys

# --- Systemd user services for media ---
# Remove legacy custom mpdris2.service (replaced by drop-in for RPM unit)
mpdris2_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.config/systemd/user/mpdris2.service

# Drop-in override for RPM-shipped mpDris2.service: adds MPD ordering
mpdris2_user_service:
  file.managed:
    - name: {{ home }}/.config/systemd/user/mpDris2.service.d/override.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        After=mpd.service
        Wants=mpd.service

mpdris2_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
    - onchanges:
      - file: mpdris2_user_service

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
enable_user_services:
  cmd.run:
    - name: |
        set -eo pipefail
        systemctl --user daemon-reload
        systemctl --user enable {{ us.enable_services | join(' ') }}
        systemctl --user enable --now {{ us.enable_now_timers | join(' ') }}
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - unless: |
{% for svc in us.enable_services + us.enable_now_timers %}
        systemctl --user is-enabled {{ svc }} 2>/dev/null{{ ' &&' if not loop.last else '' }}
{% endfor %}
    - require:
{% for unit in us.unit_files %}
      - file: {{ unit.id }}
{% endfor %}
