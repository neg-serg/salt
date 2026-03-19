{% from '_imports.jinja' import host, user, home, pkg_list, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_install.jinja' import curl_extract_7z %}
{% from '_macros_config.jinja' import config_file_edit %}
{% import_yaml 'data/versions.yaml' as ver %}
# Steam + gaming tools (native pacman install)
# Requires multilib repo for lib32 dependencies.
# Inline cmd.run (not pacman_install macro): --ask 4 resolves CachyOS
# lib32-mesa-git vs multilib lib32-mesa conflict; macro doesn't support extra args.
{% set modern_skin_version = ver.get('modern_steam', '') %}

{{ config_file_edit('multilib_repo',
    cmd="printf '\\n[multilib]\\nInclude = /etc/pacman.d/mirrorlist\\n' >> /etc/pacman.conf && pacman -Sy",
    check_pattern='^\\[multilib\\]',
    check_file='/etc/pacman.conf',
    retry=True) }}

vulkan_radeon_pkg:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 vulkan-radeon lib32-vulkan-radeon
    - unless: rg -qx 'vulkan-radeon' {{ pkg_list }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: multilib_repo

steam_pkg:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 steam gamescope mangohud goverlay gamemode protontricks
    - unless: rg -qx 'steam' {{ pkg_list }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: vulkan_radeon_pkg

{{ ensure_dir('steam_library_dir', host.mnt_zero ~ '/steam/steamapps', require=['mount: mount_zero']) }}

{{ ensure_dir('steam_skins_dir', home ~ '/.local/share/Steam/skins') }}

{{ pacman_install('p7zip', '7zip') }}

{{ curl_extract_7z('modern_steam_skin', 'https://github.com/SleepDaemon/Modern-Steam/releases/download/v' ~ modern_skin_version ~ '/SteamDarkMode.7z', home ~ '/.local/share/Steam/skins', creates=home ~ '/.local/share/Steam/skins/steamui', version=modern_skin_version if modern_skin_version else None, user=user, require=['cmd: install_p7zip', 'file: steam_skins_dir']) }}

# Activate Modern-Steam CSS skin: symlink *.custom.css into Steam's
# steamui/ and clientui/ directories where the new UI auto-loads them.
{% set skins = home ~ '/.local/share/Steam/skins' %}
{% set steam = home ~ '/.local/share/Steam' %}
{% for css_pair in [
  (skins ~ '/steamui/config.css', steam ~ '/steamui/config.css'),
  (skins ~ '/steamui/libraryroot.custom.css', steam ~ '/steamui/libraryroot.custom.css'),
  (skins ~ '/clientui/friends.custom.css', steam ~ '/clientui/friends.custom.css'),
  (skins ~ '/clientui/ofriends.custom.css', steam ~ '/clientui/ofriends.custom.css'),
] %}
steam_skin_link_{{ loop.index }}:
  file.symlink:
    - name: {{ css_pair[1] }}
    - target: {{ css_pair[0] }}
    - user: {{ user }}
    - group: {{ user }}
    - force: True
    - onlyif: test -f {{ css_pair[0] }}
    - require:
      - cmd: install_modern_steam_skin
{% endfor %}

gamemode_config:
  file.managed:
    - name: /etc/gamemode.ini
    - source: salt://configs/gamemode.ini
    - mode: '0644'
    - require:
      - cmd: steam_pkg

gamemode_start_script:
  file.managed:
    - name: /usr/local/bin/gamemode-start.sh
    - source: salt://scripts/gamemode-start.sh
    - mode: '0755'
    - require:
      - cmd: steam_pkg

gamemode_end_script:
  file.managed:
    - name: /usr/local/bin/gamemode-end.sh
    - source: salt://scripts/gamemode-end.sh
    - mode: '0755'
    - require:
      - cmd: steam_pkg

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
      - cmd: steam_pkg
