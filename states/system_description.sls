{% from '_imports.jinja' import host, user, home, pkg_list %}
# Salt state for CachyOS workstation — top-level orchestrator
# Packages installed via pacman/paru outside Salt; Salt handles configuration

pacman_db_warmup:
  cmd.run:
    - name: pacman -Qq > {{ pkg_list }}

system_timezone:
  timezone.system:
    - name: Europe/Moscow

system_locale:
  file.managed:
    - name: /etc/locale.conf
    - contents: 'LANG=en_US.UTF-8'

system_keymap:
  cmd.run:
    - name: localectl set-x11-keymap ru,us
    - unless: rg -q 'ru' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null

system_hostname:
  file.managed:
    - name: /etc/hostname
    - contents: {{ host.hostname }}

include:
  - audio
  - amnezia
  - bind_mounts
  - custom_pkgs
  - desktop
  - dns
  - floorp
  - fonts
  - greetd
  - hardware
  - installers
  - installers_desktop
  - kanata
  - installers_themes
  - kernel_modules
  - kernel_params_limine
  - monitoring
  - mounts
  - mpd
  - network
  - ollama
  - services
  - snapshots
  - steam
  - sysctl
  - users
  - user_services
  - zsh
