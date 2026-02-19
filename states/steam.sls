{% from '_imports.jinja' import host, user, home, pkg_list %}
{% from '_macros_service.jinja' import ensure_dir %}
# Steam + gaming tools (native pacman install)
# Requires multilib repo for lib32 dependencies;
# --ask 4 resolves CachyOS lib32-mesa-git vs multilib lib32-mesa conflict.
{% if host.features.steam %}

enable_multilib:
  file.blockreplace:
    - name: /etc/pacman.conf
    - source: salt://configs/pacman-multilib.conf
    - marker_start: '# SALT managed: multilib {'
    - marker_end: '# SALT managed: multilib }'
    - append_if_not_found: True

sync_multilib:
  cmd.run:
    - name: pacman -Sy
    - onchanges:
      - file: enable_multilib

install_vulkan_radeon:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 vulkan-radeon lib32-vulkan-radeon
    - unless: rg -qx 'vulkan-radeon' {{ pkg_list }}
    - require:
      - cmd: sync_multilib

install_steam:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 steam gamescope mangohud goverlay gamemode protontricks
    - unless: rg -qx 'steam' {{ pkg_list }}
    - require:
      - cmd: install_vulkan_radeon

{{ ensure_dir('steam_library_dir', host.mnt_zero ~ '/steam/steamapps') }}

{{ ensure_dir('steam_skins_dir', home ~ '/.local/share/Steam/skins') }}

ensure_7z:
  cmd.run:
    - name: pacman -S --noconfirm --needed p7zip
    - unless: command -v 7z

download_modern_steam:
  cmd.run:
    - name: |
        set -eo pipefail
        TMPDIR=$(mktemp -d)
        curl -fsSL https://github.com/SleepDaemon/Modern-Steam/releases/download/v0.2.7/SteamDarkMode.7z -o "$TMPDIR/SteamDarkMode.7z"
        7z x -aoa "$TMPDIR/SteamDarkMode.7z" -o{{ home }}/.local/share/Steam/skins/
        rm -rf "$TMPDIR"
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/share/Steam/skins/steamui
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
        changed=0
        for prefix in ~/.steam/root/steamapps/compatdata/*/pfx; do
          [ -d "$prefix" ] || continue
          if [ ! -f "$prefix/dxvk.conf" ]; then
            WINEPREFIX="$prefix" wine reg add "HKEY_CURRENT_USER\Software\Wine\Explorer\Desktops" /v Default /d "3840x2160" /f 2>/dev/null || true
            printf '%s\n' \
              'd3d11.allowDiscard = True' \
              'd3d11.enumerateDisplayModes = 1' \
              'dxgi.deferSurfaceCreation = 0' \
              > "$prefix/dxvk.conf"
            changed=$((changed + 1))
          fi
        done
        [ "$changed" -gt 0 ] && echo "Configured $changed prefix(es)" || echo "All prefixes already configured"
    - shell: /bin/bash
    - runas: {{ user }}
    - unless: |
        for prefix in ~/.steam/root/steamapps/compatdata/*/pfx; do
          [ -d "$prefix" ] && [ ! -f "$prefix/dxvk.conf" ] && exit 1
        done
        exit 0
    - require:
      - cmd: install_steam
{% endif %}
