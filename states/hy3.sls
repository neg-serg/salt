{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}
# hy3 Hyprland plugin (installed via pacman/AUR on CachyOS)

{{ home }}/.local/lib/hyprland:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

check_hy3:
  cmd.run:
    - name: echo "hy3 plugin present"
    - unless: test -f {{ home }}/.local/lib/hyprland/libhy3.so
    - onlyif: pacman -Q hyprland
    - require:
      - file: {{ home }}/.local/lib/hyprland
