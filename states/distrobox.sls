# Salt state for Distrobox container management
# Manages gaming containers declaratively via distrobox assemble

steam_library_dir:
  file.directory:
    - name: /mnt/zero/steam/steamapps
    - user: neg
    - group: neg
    - makedirs: True

distrobox_steam:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox assemble create --file /home/neg/.config/distrobox/steam.ini
    - runas: neg
    - unless: podman container exists steam
    - onlyif: command -v distrobox

steam_install_deps:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox enter steam -- sudo pacman -S --noconfirm --needed lib32-libdisplay-info
    - runas: neg
    - unless: distrobox enter steam -- pacman -Q lib32-libdisplay-info 2>/dev/null
    - require:
      - cmd: distrobox_steam

steam_export_app:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox enter steam -- distrobox-export --app steam
    - runas: neg
    - unless: grep -q 'distrobox-enter.*-n steam.*steam' /home/neg/.local/share/applications/steam-steam.desktop 2>/dev/null
    - require:
      - cmd: distrobox_steam

steam_export_bin:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox enter steam -- distrobox-export --bin /usr/bin/steam --export-path /home/neg/.local/bin
    - runas: neg
    - creates: /home/neg/.local/bin/steam
    - require:
      - cmd: distrobox_steam
