{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}
# Steam + gaming tools (native pacman install)
# Requires multilib repo for lib32 dependencies;
# --ask 4 resolves CachyOS lib32-mesa-git vs multilib lib32-mesa conflict.
{% if host.features.steam %}

enable_multilib:
  file.append:
    - name: /etc/pacman.conf
    - text: |

        [multilib]
        Include = /etc/pacman.d/mirrorlist
    - unless: rg -q '^\[multilib\]' /etc/pacman.conf

sync_multilib:
  cmd.run:
    - name: pacman -Sy
    - onchanges:
      - file: enable_multilib

install_vulkan_radeon:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 vulkan-radeon lib32-vulkan-radeon
    - unless: rg -qx 'vulkan-radeon' /var/cache/salt/pacman_installed.txt
    - require:
      - cmd: sync_multilib

install_steam:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 steam gamescope mangohud goverlay gamemode protontricks
    - unless: rg -qx 'steam' /var/cache/salt/pacman_installed.txt
    - require:
      - cmd: install_vulkan_radeon

steam_library_dir:
  file.directory:
    - name: /mnt/zero/steam/steamapps
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

steam_skins_dir:
  file.directory:
    - name: {{ home }}/.local/share/Steam/skins
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

ensure_7z:
  cmd.run:
    - name: pacman -S --noconfirm --needed p7zip
    - unless: rg -qx 'p7zip' /var/cache/salt/pacman_installed.txt

download_modern_steam:
  cmd.run:
    - name: |
        set -eo pipefail
        TMPDIR=$(mktemp -d)
        curl -fsSL https://github.com/SleepDaemon/Modern-Steam/releases/download/v0.2.7/SteamDarkMode.7z -o "$TMPDIR/SteamDarkMode.7z"
        7z x "$TMPDIR/SteamDarkMode.7z" -o{{ home }}/.local/share/Steam/skins/
        rm -rf "$TMPDIR"
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/share/Steam/skins/SteamDarkMode
    - require:
      - cmd: ensure_7z
      - file: steam_skins_dir

# Fix DXVK resolution detection for all Proton prefixes
# This ensures games properly enumerate all available display modes
# Issue: DXVK sometimes reports only a subset of resolutions to games
dxvk_resolution_fix:
  cmd.run:
    - name: |
        set -eo pipefail
        for prefix in ~/.steam/root/steamapps/compatdata/*/pfx; do
          if [ -d "$prefix" ]; then
            # Register correct desktop resolution in wine registry
            WINEPREFIX="$prefix" wine reg add "HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops" /v Default /d "3840x2160" /f 2>/dev/null || true

            # Create DXVK config if not present
            if [ ! -f "$prefix/dxvk.conf" ]; then
              printf '%s\n' \
                '# DXVK Configuration for proper display mode enumeration' \
                '# Fixes issue where games only see subset of available resolutions' \
                '# This is especially important for high-resolution displays (4K, ultrawide)' \
                '' \
                'd3d11.allowDiscard = True' \
                'd3d11.enumerateDisplayModes = 1' \
                'dxgi.deferSurfaceCreation = 0' \
                > "$prefix/dxvk.conf"
            fi
          fi
        done
    - shell: /bin/bash
    - runas: {{ user }}
    - require:
      - cmd: install_steam
{% endif %}
