{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import user_service_with_unit %}
# Espanso: cross-platform text expander (Wayland variant)

# --- Install espanso-wayland from AUR ---
{{ paru_install('espanso', 'espanso-wayland') }}

# --- Systemd user service ---
# Config files managed by chezmoi (dotfiles/dot_config/espanso/)
{{ user_service_with_unit('espanso', 'espanso.service',
     start_now=['espanso.service'],
     requires=['cmd: install_espanso']) }}

# --- Health check ---
espanso_healthcheck:
  cmd.run:
    - name: espanso status
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - unless: espanso status 2>/dev/null | rg -q running
    - require:
      - cmd: espanso_enabled
