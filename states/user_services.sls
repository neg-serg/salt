{% from 'host_config.jinja' import host %}
{% from '_macros_service.jinja' import user_service_file %}
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
{{ user_service_file('mbsync_gmail_service', 'mbsync-gmail.service') }}
{{ user_service_file('mbsync_gmail_timer', 'mbsync-gmail.timer') }}
{{ user_service_file('imapnotify_gmail_service', 'imapnotify-gmail.service') }}
{{ user_service_file('vdirsyncer_service', 'vdirsyncer.service') }}
{{ user_service_file('vdirsyncer_timer', 'vdirsyncer.timer') }}
{{ user_service_file('surfingkeys_server_service', 'surfingkeys-server.service') }}
{{ user_service_file('pic_dirs_list_service', 'pic-dirs-list.service') }}
{{ user_service_file('vicinae_service', 'vicinae.service') }}

# --- Enable user services: single daemon-reload + batch enable ---
enable_user_services:
  cmd.run:
    - name: |
        set -eo pipefail
        systemctl --user daemon-reload
        systemctl --user enable imapnotify-gmail.service surfingkeys-server.service pic-dirs-list.service vicinae.service gpg-agent.socket gpg-agent-ssh.socket
        systemctl --user enable --now mbsync-gmail.timer vdirsyncer.timer
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - unless: |
        systemctl --user is-enabled imapnotify-gmail.service 2>/dev/null &&
        systemctl --user is-enabled mbsync-gmail.timer 2>/dev/null &&
        systemctl --user is-enabled vdirsyncer.timer 2>/dev/null &&
        systemctl --user is-enabled surfingkeys-server.service 2>/dev/null &&
        systemctl --user is-enabled pic-dirs-list.service 2>/dev/null &&
        systemctl --user is-enabled vicinae.service 2>/dev/null &&
        systemctl --user is-enabled gpg-agent-ssh.socket 2>/dev/null
    - require:
      - file: imapnotify_gmail_service
      - file: mbsync_gmail_timer
      - file: vdirsyncer_timer
      - file: surfingkeys_server_service
      - file: pic_dirs_list_service
      - file: vicinae_service
