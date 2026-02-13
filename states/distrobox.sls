# Salt state for Distrobox container management
# Manages gaming containers declaratively via distrobox assemble
{% from '_macros.jinja' import selinux_fcontext %}

# SELinux: relabel games dir so container can write to it
# /var/mnt → /mnt in semanage per Fedora Atomic equivalency
{{ selinux_fcontext('steam_games_selinux', '/mnt/zero/games', '/var/mnt/zero/games', 'user_home_t') }}

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
