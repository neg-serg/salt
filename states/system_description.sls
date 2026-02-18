{% from 'host_config.jinja' import host %}
# Salt state for CachyOS workstation — top-level orchestrator
# Packages installed via pacman/paru outside Salt; Salt handles configuration

pacman_db_warmup:
  cmd.run:
    - name: pacman -Qq > /var/cache/salt/pacman_installed.txt

system_timezone:
  timezone.system:
    - name: Europe/Moscow

system_locale_keymap:
  cmd.run:
    - name: |
        set -eo pipefail
        localectl set-locale LANG=en_US.UTF-8
        localectl set-x11-keymap ru,us
    - unless: |
        rg -q 'LANG=en_US.UTF-8' /etc/locale.conf 2>/dev/null &&
        rg -q 'ru' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null

system_hostname:
  cmd.run:
    - name: hostnamectl set-hostname {{ host.hostname }}
    - unless: rg -qx '{{ host.hostname }}' /etc/hostname

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
  - hy3
  - installers
  - installers_desktop
  - installers_themes
  - kernel_modules
  - kernel_params_limine
  - monitoring
  - mounts
  - mpd
  - network
  - ollama
  - services
  - steam
  - sysctl
  - users
  - user_services
  - zsh
