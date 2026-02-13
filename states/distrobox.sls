# Salt state for Distrobox container management
# Manages gaming containers declaratively via distrobox assemble

# SELinux: relabel games dir so container can write to it
# /var/mnt → /mnt in semanage per Fedora Atomic equivalency
steam_games_selinux:
  cmd.run:
    - name: |
        semanage fcontext -a -t user_home_t "/mnt/zero/games(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t user_home_t "/mnt/zero/games(/.*)?"
        restorecon -Rv /var/mnt/zero/games
    - unless: ls -dZ /var/mnt/zero/games | grep -q user_home_t

distrobox_steam:
  cmd.run:
    - name: |
        unset SUDO_USER SUDO_UID SUDO_GID SUDO_COMMAND
        distrobox assemble create --file /var/home/neg/.config/distrobox/steam.ini
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
