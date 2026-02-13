# Salt state for Distrobox container management
# Manages gaming containers declaratively via distrobox assemble

distrobox_steam:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox assemble create --file /var/home/neg/.config/distrobox/distrobox.ini
    - runas: neg
    - unless: podman container exists steam
    - onlyif: command -v distrobox

steam_export_app:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox enter steam -- distrobox-export --app steam
    - runas: neg
    - unless: grep -q 'distrobox-enter.*-n steam.*steam' /var/home/neg/.local/share/applications/steam-steam.desktop 2>/dev/null
    - require:
      - cmd: distrobox_steam

steam_export_bin:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox enter steam -- distrobox-export --bin /usr/bin/steam --export-path /var/home/neg/.local/bin
    - runas: neg
    - creates: /var/home/neg/.local/bin/steam
    - require:
      - cmd: distrobox_steam
