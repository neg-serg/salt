{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, user_service_with_unit %}
# Espanso: cross-platform text expander (Wayland variant)

# --- Install espanso-wayland from AUR ---
{{ paru_install('espanso', 'espanso-wayland') }}

# --- Config directories ---
{{ ensure_dir('espanso_config_dir', home ~ '/.config/espanso/config') }}
{{ ensure_dir('espanso_match_dir', home ~ '/.config/espanso/match') }}

# --- Global config (Salt-authoritative, replaced on every apply) ---
espanso_config:
  file.managed:
    - name: {{ home }}/.config/espanso/config/default.yml
    - source: salt://configs/espanso-default.yml
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - require:
      - file: espanso_config_dir

# --- Starter match snippets (seed only — user edits preserved) ---
espanso_matches:
  file.managed:
    - name: {{ home }}/.config/espanso/match/base.yml
    - source: salt://configs/espanso-base-matches.yml
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - replace: False
    - require:
      - file: espanso_match_dir

# --- Systemd user service ---
{{ user_service_with_unit('espanso', 'espanso.service',
     start_now=['espanso.service'],
     requires=['cmd: install_espanso', 'file: espanso_config']) }}

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
