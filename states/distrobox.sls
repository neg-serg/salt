# Salt state for Distrobox container management
# Manages gaming containers declaratively via distrobox assemble

distrobox_steam:
  cmd.run:
    - name: distrobox assemble create --file /var/home/neg/.config/distrobox/distrobox.ini
    - runas: neg
    - unless: podman container exists steam
    - onlyif: command -v distrobox

steam_export:
  cmd.run:
    - name: distrobox enter steam -- distrobox-export --app steam
    - runas: neg
    - creates: /var/home/neg/.local/share/applications/steam.desktop
    - require:
      - cmd: distrobox_steam
