{% from 'host_config.jinja' import host %}
{% set user = host.user %}
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
    - unless: grep -q '^\[multilib\]' /etc/pacman.conf

sync_multilib:
  cmd.run:
    - name: pacman -Sy
    - onchanges:
      - file: enable_multilib

install_vulkan_radeon:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 vulkan-radeon lib32-vulkan-radeon
    - unless: pacman -Q vulkan-radeon
    - require:
      - cmd: sync_multilib

install_steam:
  cmd.run:
    - name: pacman -S --noconfirm --needed --ask 4 steam gamescope mangohud gamemode protontricks
    - unless: pacman -Q steam
    - require:
      - cmd: install_vulkan_radeon

steam_library_dir:
  file.directory:
    - name: /mnt/zero/steam/steamapps
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
{% endif %}
