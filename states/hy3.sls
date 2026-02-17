{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}
# hy3 Hyprland plugin (installed via pacman/AUR on CachyOS)
{% if host.features.hy3 %}

{{ home }}/.local/lib/hyprland:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

check_hy3:
  cmd.run:
    - name: echo "hy3 plugin present"
    - unless: test -f {{ home }}/.local/lib/hyprland/libhy3.so
    - onlyif: grep -qx 'hyprland' /var/cache/salt/pacman_installed.txt
    - require:
      - file: {{ home }}/.local/lib/hyprland
{% endif %}
