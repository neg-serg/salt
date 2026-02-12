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

steam_export:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox enter steam -- distrobox-export --app steam
    - runas: neg
    - creates: /var/home/neg/.local/share/applications/steam.desktop
    - require:
      - cmd: distrobox_steam
