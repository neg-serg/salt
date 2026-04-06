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

{{ config_file_edit('multilib_repo',
    cmd="printf '\\n[multilib]\\nInclude = /etc/pacman.d/mirrorlist\\n' >> /etc/pacman.conf && pacman -Sy",
    check_pattern='^\\[multilib\\]',
    check_file='/etc/pacman.conf',
    retry=True) }}

vulkan_radeon_pkg:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 vulkan-radeon lib32-vulkan-radeon
    - unless: grep -qxF 'vulkan-radeon' {{ pkg_list }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: pacman_db_warmup
      - cmd: multilib_repo

steam_pkg:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 steam gamescope mangohud goverlay gamemode protontricks
    - unless: grep -qxF 'steam' {{ pkg_list }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: vulkan_radeon_pkg

{{ ensure_dir('steam_library_dir', host.mnt_zero ~ '/steam/steamapps', require=['mount: mount_zero']) }}
{{ pacman_install('p7zip', '7zip') }}

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
