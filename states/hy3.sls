# hy3 Hyprland plugin (installed via pacman/AUR on CachyOS)

/home/neg/.local/lib/hyprland:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

check_hy3:
  cmd.run:
    - name: echo "hy3 plugin present"
    - unless: test -f /home/neg/.local/lib/hyprland/libhy3.so
    - onlyif: pacman -Q hyprland
    - require:
      - file: /home/neg/.local/lib/hyprland
