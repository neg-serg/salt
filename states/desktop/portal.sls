{% from '_imports.jinja' import host, home, user %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir %}

# --- XDG Desktop Portal backend selection ---
# Uses xdg-desktop-portal-termfilechooser + yazi for file dialogs.

# Portal configuration — selects which backend handles each interface
{{ ensure_dir('portal_conf_dir', home ~ '/.config/xdg-desktop-portal', mode='0755') }}

portal_config:
  file.managed:
    - name: {{ home }}/.config/xdg-desktop-portal/hyprland-portals.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - replace: False
    - contents: |
        [preferred]
        default=hyprland;gtk
        org.freedesktop.impl.portal.FileChooser=termfilechooser
    - require:
      - file: portal_conf_dir

# termfilechooser backend (yazi-based file chooser)
{{ paru_install('xdg_termfilechooser', 'xdg-desktop-portal-termfilechooser-boydaihungst-git') }}

# Restart portal after config changes so the new backend takes effect
portal_restart:
  cmd.run:
    - name: systemctl --user restart xdg-desktop-portal.service
    - runas: {{ user }}
    - onchanges:
      - file: portal_config
