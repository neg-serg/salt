{% from '_imports.jinja' import host, home, user %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir %}

# --- XDG Desktop Portal backend selection ---
# When kitty_desktop_ui is enabled, kitty's built-in desktop-ui kitten handles
# both FileChooser (choose-files) and Settings (color-scheme) portals.
# When disabled, xdg-desktop-portal-termfilechooser + yazi is used instead.

{% set kitty_ui = host.features.get('kitty_desktop_ui', false) %}

# Portal configuration — selects which backend handles each interface
{{ ensure_dir('portal_conf_dir', home ~ '/.config/xdg-desktop-portal', mode='0755') }}

portal_config:
  file.managed:
    - name: {{ home }}/.config/xdg-desktop-portal/hyprland-portals.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - contents: |
        [preferred]
{% if kitty_ui %}
        default=hyprland;kitty;gtk
        org.freedesktop.impl.portal.FileChooser=kitty
        org.freedesktop.impl.portal.Settings=kitty
{% else %}
        default=hyprland;gtk
        org.freedesktop.impl.portal.FileChooser=termfilechooser
{% endif %}
    - require:
      - file: portal_conf_dir

{% if kitty_ui %}
# kitty desktop-ui portal: enable D-Bus autostart and config
portal_kitty_enable:
  cmd.run:
    - name: kitten desktop-ui enable-portal
    - runas: {{ user }}
    - unless: test -f {{ home }}/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.kitty.service

portal_kitty_config:
  file.managed:
    - name: {{ home }}/.config/kitty/desktop-ui-portal.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - contents: |
        # kitty desktop-ui portal configuration
        color_scheme dark
        accent_color cyan
        contrast normal

{% else %}
# termfilechooser backend (yazi-based file chooser)
{{ paru_install('xdg_termfilechooser', 'xdg-desktop-portal-termfilechooser-boydaihungst-git') }}

# Clean up kitty portal artifacts when switching back
portal_kitty_config_absent:
  file.absent:
    - name: {{ home }}/.config/kitty/desktop-ui-portal.conf
{% endif %}

# Restart portal after config changes so the new backend takes effect
portal_restart:
  cmd.run:
    - name: systemctl --user restart xdg-desktop-portal.service
    - runas: {{ user }}
    - onchanges:
      - file: portal_config
