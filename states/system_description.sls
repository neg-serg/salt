{% from '_imports.jinja' import host, user, pkg_list %}
{% from '_macros_service.jinja' import ensure_dir %}
# Salt state for CachyOS workstation — top-level orchestrator
# Packages managed via packages.sls (data/packages.yaml) + domain-specific states

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
  # ── Core (always included) ──────────────────────────────────────────
  # User accounts, shell, disk mounts — foundations for everything else
  - os_release
  - users
  - zsh
  - mounts
  - bind_mounts

  # Kernel tuning, hardware, sysctl
  - kernel_modules
  - kernel_params_limine
  - mkinitcpio
  - sysctl
  - hardware

  # Desktop: audio stack, DE config, login manager, fonts
  - audio
  - desktop
  - fonts
  - greetd

  # Shared systemd-managed service identities and paths
  - systemd_resources

  # Network: DNS
  - dns
  - network

  # Packages: base system, CLI tools, desktop apps, themes, custom PKGBUILDs
  - packages
  - installers
  - installers_mpv
  - installers_desktop
  - installers_themes
  - custom_pkgs

  # Services, monitoring, user units, snapshots
  - services
  - monitoring_alerts
  - user_services
  - snapshots
  - code_rag

  # ── Feature-gated (skipped entirely when disabled) ──────────────────
{% if host.features.amnezia %}
  - amnezia
{% endif %}
{% if host.features.flatpak %}
  - flatpak
{% endif %}
{% if host.features.get('espanso', false) %}
  - espanso
{% endif %}
{% if host.features.floorp %}
  - floorp
{% endif %}
{% if host.zen_profile %}
  - zen_browser
{% endif %}
{% if host.features.kanata %}
  - kanata
{% endif %}
{% if host.features.mpd %}
  - mpd
{% endif %}
{% if host.features.get('music_analysis') %}
  - music_analysis
{% endif %}
{% if host.features.tidal %}
  - tidal
{% endif %}
{% if host.features.ollama %}
  - ollama
{% endif %}
{% if host.features.llama_embed %}
  - llama_embed
{% endif %}
{% if host.features.opencode %}
  - opencode
{% endif %}
{% if host.features.openclaw %}
  - openclaw_agent
{% endif %}
{% if host.features.get('nanoclaw', false) %}
  - nanoclaw
{% endif %}
{% if host.features.get('telethon_bridge', false) %}
  - telethon_bridge
{% endif %}
{% if host.features.get('opencode_telegram', false) %}
  - opencode_telegram
{% endif %}
{% if host.features.get('image_gen', True) %}
  - image_generation
{% endif %}
{% if host.features.get('video_ai', False) %}
  - video_ai
{% endif %}
{% if host.features.steam %}
  - steam
{% endif %}
{% if host.features.monitoring.loki %}
  - monitoring_loki
{% endif %}
{% if host.features.network.get('zapret2', false) %}
  - zapret2
{% endif %}
