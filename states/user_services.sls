# Systemd user services: mail, calendar, chezmoi, media, surfingkeys

# --- Systemd user services for media ---
# Remove legacy custom mpdris2.service (replaced by drop-in for RPM unit)
mpdris2_legacy_cleanup:
  file.absent:
    - name: /home/neg/.config/systemd/user/mpdris2.service

# Drop-in override for RPM-shipped mpDris2.service: adds MPD ordering
mpdris2_user_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/mpDris2.service.d/override.conf
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        After=mpd.service
        Wants=mpd.service

mpdris2_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
    - onchanges:
      - file: mpdris2_user_service

chezmoi_config:
  file.managed:
    - name: /home/neg/.config/chezmoi/chezmoi.toml
    - source: salt://dotfiles/dot_config/chezmoi/chezmoi.toml
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True

chezmoi_source_symlink:
  file.symlink:
    - name: /home/neg/.local/share/chezmoi
    - target: /home/neg/src/salt/dotfiles
    - user: neg
    - group: neg
    - force: True
    - makedirs: True
    - require:
      - user: user_neg
      - file: chezmoi_config

# --- Mail directories (needed by mbsync) ---
mail_directories:
  file.directory:
    - names:
      - /home/neg/.local/mail/gmail/INBOX
      - /home/neg/.local/mail/gmail/[Gmail]/Sent Mail
      - /home/neg/.local/mail/gmail/[Gmail]/Drafts
      - /home/neg/.local/mail/gmail/[Gmail]/All Mail
      - /home/neg/.local/mail/gmail/[Gmail]/Trash
      - /home/neg/.local/mail/gmail/[Gmail]/Spam
    - user: neg
    - group: neg
    - makedirs: True

# --- Systemd user services for mail ---
mbsync_gmail_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/mbsync-gmail.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Mailbox synchronization (Gmail)
        After=network-online.target
        Wants=network-online.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/mbsync -c %h/.config/mbsync/mbsyncrc gmail
        [Install]
        WantedBy=default.target

mbsync_gmail_timer:
  file.managed:
    - name: /home/neg/.config/systemd/user/mbsync-gmail.timer
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Mailbox synchronization timer (Gmail)
        [Timer]
        OnBootSec=2min
        OnUnitActiveSec=10min
        [Install]
        WantedBy=timers.target

imapnotify_gmail_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/imapnotify-gmail.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=IMAP IDLE notifications (Gmail)
        After=network-online.target
        Wants=network-online.target
        [Service]
        ExecStart=/usr/bin/goimapnotify -conf %h/.config/imapnotify/gmail.json
        Restart=on-failure
        RestartSec=30
        [Install]
        WantedBy=default.target

# --- Systemd user services for calendar ---
vdirsyncer_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/vdirsyncer.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Synchronize calendars and contacts (vdirsyncer)
        After=network-online.target
        Wants=network-online.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/vdirsyncer sync

vdirsyncer_timer:
  file.managed:
    - name: /home/neg/.config/systemd/user/vdirsyncer.timer
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Synchronize calendars and contacts timer
        [Timer]
        OnBootSec=2min
        OnUnitActiveSec=5min
        [Install]
        WantedBy=timers.target

# --- Surfingkeys HTTP server (browser extension helper) ---
surfingkeys_server_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/surfingkeys-server.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Surfingkeys HTTP server (browser extension helper)
        After=graphical-session.target
        PartOf=graphical-session.target
        [Service]
        ExecStart=%h/.local/bin/surfingkeys-server
        Restart=on-failure
        RestartSec=5
        [Install]
        WantedBy=graphical-session.target

# --- Pic dirs indexer (inotifywait + zoxide) ---
pic_dirs_list_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/pic-dirs-list.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Index picture directories into zoxide on changes
        After=graphical-session.target
        PartOf=graphical-session.target
        [Service]
        ExecStart=%h/.local/bin/pic-dirs-list
        Restart=on-failure
        RestartSec=5
        Environment=XDG_PICTURES_DIR=%h/pic
        [Install]
        WantedBy=graphical-session.target

# --- Vicinae: application launcher daemon ---
vicinae_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/vicinae.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Unit]
        Description=Vicinae Launcher Daemon
        Documentation=https://docs.vicinae.com
        After=graphical-session.target
        Requires=dbus.socket
        PartOf=graphical-session.target
        [Service]
        Type=simple
        ExecStart=/usr/bin/vicinae server --replace
        ExecReload=/bin/kill -HUP $MAINPID
        Restart=on-failure
        RestartSec=60
        KillMode=process
        [Install]
        WantedBy=graphical-session.target

# --- Enable user services: single daemon-reload + batch enable ---
enable_user_services:
  cmd.run:
    - name: |
        systemctl --user daemon-reload
        systemctl --user enable imapnotify-gmail.service surfingkeys-server.service pic-dirs-list.service gpg-agent.socket gpg-agent-ssh.socket
        systemctl --user enable --now mbsync-gmail.timer vdirsyncer.timer
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - unless: |
        systemctl --user is-enabled imapnotify-gmail.service 2>/dev/null &&
        systemctl --user is-enabled mbsync-gmail.timer 2>/dev/null &&
        systemctl --user is-enabled vdirsyncer.timer 2>/dev/null &&
        systemctl --user is-enabled surfingkeys-server.service 2>/dev/null &&
        systemctl --user is-enabled pic-dirs-list.service 2>/dev/null &&
        systemctl --user is-enabled gpg-agent-ssh.socket 2>/dev/null
    - require:
      - file: imapnotify_gmail_service
      - file: mbsync_gmail_timer
      - file: vdirsyncer_timer
      - file: surfingkeys_server_service
      - file: pic_dirs_list_service
