{% from '_imports.jinja' import host, user, home, pkg_list, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% import_yaml 'data/versions.yaml' as ver %}
# Steam + gaming tools (native pacman install)
# Requires multilib repo for lib32 dependencies;
# --ask 4 resolves CachyOS lib32-mesa-git vs multilib lib32-mesa conflict.
{% if host.features.steam %}

multilib_repo:
  cmd.run:
    - name: |
        set -eo pipefail
        cat >> /etc/pacman.conf << 'EOF'

        [multilib]
        Include = /etc/pacman.d/mirrorlist
        EOF
        pacman -Sy
    - unless: rg -q '^\[multilib\]' /etc/pacman.conf
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

install_vulkan_radeon:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 vulkan-radeon lib32-vulkan-radeon
    - unless: rg -qx 'vulkan-radeon' {{ pkg_list }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: multilib_repo

install_steam:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 steam gamescope mangohud goverlay gamemode protontricks
    - unless: rg -qx 'steam' {{ pkg_list }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: install_vulkan_radeon

{{ ensure_dir('steam_library_dir', host.mnt_zero ~ '/steam/steamapps') }}

{{ ensure_dir('steam_skins_dir', home ~ '/.local/share/Steam/skins') }}

{{ pacman_install('p7zip', 'p7zip') }}

modern_steam_skin:
  cmd.run:
    - name: |
        set -eo pipefail
        TMPDIR=$(mktemp -d)
        curl -fsSL https://github.com/SleepDaemon/Modern-Steam/releases/download/v{{ ver.modern_steam }}/SteamDarkMode.7z -o "$TMPDIR/SteamDarkMode.7z"
        7z x -aoa "$TMPDIR/SteamDarkMode.7z" -o{{ home }}/.local/share/Steam/skins/
        rm -rf "$TMPDIR"
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/share/Steam/skins/steamui
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: install_p7zip
      - file: steam_skins_dir

dxvk_resolution_fix:
  cmd.script:
    - source: salt://scripts/dxvk-resolution-fix.sh
    - shell: /bin/bash
    - runas: {{ user }}
{%- if host.display %}
    - env:
      - DXVK_RESOLUTION: "{{ host.display.split('@')[0] }}"
{%- endif %}
    - unless: |
        for prefix in ~/.steam/root/steamapps/compatdata/*/pfx; do
          [ -d "$prefix" ] && [ ! -f "$prefix/dxvk.conf" ] && exit 1
        done
        exit 0
    - require:
      - cmd: install_steam
{% endif %}
