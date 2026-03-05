{% from '_imports.jinja' import host, user, pkg_list %}
{% from '_macros_service.jinja' import ensure_dir %}
# Salt state for CachyOS workstation — top-level orchestrator
# Packages installed via pacman/paru outside Salt; Salt handles configuration

pacman_db_warmup:
  cmd.run:
    - name: |
        _tmp=$(mktemp)
        pacman -Qq > "$_tmp"
        if cmp -s "$_tmp" {{ pkg_list }}; then
          rm "$_tmp"
          echo "changed=no"
        else
          mv "$_tmp" {{ pkg_list }}
          echo "changed=yes"
        fi
    - stateful: True
    - shell: /bin/bash

system_timezone:
  timezone.system:
    - name: {{ host.timezone }}

system_locale:
  file.managed:
    - name: /etc/locale.conf
    - contents: 'LANG={{ host.locale }}'

system_keymap:
  cmd.run:
    - name: localectl set-x11-keymap ru,us
    - unless: rg -q 'ru' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null

system_hostname:
  file.managed:
    - name: /etc/hostname
    - contents: {{ host.hostname }}

{{ ensure_dir('user_version_cache_dir', host.home ~ '/.cache/salt-versions', mode='0755') }}
{{ ensure_dir('system_version_cache_dir', '/var/cache/salt/versions', mode='0755', user='root') }}
{{ ensure_dir('download_cache_dir', '/var/cache/salt/downloads', mode='0755') }}

include:
  # Core: user accounts, shell, disk mounts — foundations for everything else
  - users
  - zsh
  - mounts
  - bind_mounts

  # System: kernel tuning, hardware, sysctl
  - kernel_modules
  - kernel_params_limine
  - sysctl
  - hardware

  # Desktop: audio stack, DE config, login manager, fonts
  - audio
  - desktop
  - fonts
  - greetd

  # Network: DNS, proxies, VPN
  - dns
  - network
  - amnezia

  # Packages: CLI tools, desktop apps, themes, custom PKGBUILDs, flatpak
  - installers
  - installers_desktop
  - installers_themes
  - flatpak
  - custom_pkgs

  # Applications
  - floorp
  - kanata
  - mpd
  - music_analysis
  - tidal
  - ollama
  - llama_embed
  - opencode
  - steam

  # Services, monitoring, user units, snapshots
  - services
  - monitoring
  - user_services
  - snapshots
