{% from '_imports.jinja' import host, user, home, pkg_list %}
# Salt state for CachyOS workstation — top-level orchestrator
# Packages installed via pacman/paru outside Salt; Salt handles configuration

pacman_db_warmup:
  cmd.run:
    - name: pacman -Qq > {{ pkg_list }}

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

  # Packages: CLI tools, desktop apps, themes, custom PKGBUILDs
  - installers
  - installers_desktop
  - installers_themes
  - custom_pkgs

  # Applications
  - floorp
  - kanata
  - mpd
  - ollama
  - steam

  # Services, monitoring, user units, snapshots
  - services
  - monitoring
  - user_services
  - snapshots
