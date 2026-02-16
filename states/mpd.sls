{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import cargo_pkg %}
{% set user = host.user %}
{% set home = host.home %}
# MPD Native Deployment
# Salt state for setting up MPD with systemd user service and pipewire output
{% if host.features.mpd %}

include:
  - bind_mounts

# --- MPD directories ---
mpd_directories:
  file.directory:
    - names:
      - {{ home }}/.local/share/mpd
      - {{ home }}/.config/mpd/playlists
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

# --- Deploy rmpc config ---
rmpc_config_dir:
  file.directory:
    - name: {{ home }}/.config/rmpc
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

rmpc_config:
  file.recurse:
    - name: {{ home }}/.config/rmpc
    - source: salt://dotfiles/dot_config/rmpc
    - user: {{ user }}
    - group: {{ user }}

# --- Install cargo packages ---
{{ cargo_pkg('rmpc', user=user, home=home) }}

# wiremix needs custom clang args for bindgen
install_wiremix:
  cmd.run:
    - name: BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/clang/21/include" cargo install wiremix
    - runas: {{ user }}
    - creates: {{ home }}/.local/share/cargo/bin/wiremix

# --- MPD FIFO for visualizers (cava, etc.) ---
mpd_fifo:
  cmd.run:
    - name: |
        if [ ! -p /tmp/mpd.fifo ]; then
            mkfifo /tmp/mpd.fifo
            chmod 666 /tmp/mpd.fifo
        fi
    - runas: {{ user }}
    - unless: test -p /tmp/mpd.fifo

# --- Deploy mpd.conf ---
mpd_config:
  file.managed:
    - name: {{ home }}/.config/mpd/mpd.conf
    - source: salt://dotfiles/dot_config/mpd/mpd.conf
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: True

# --- Enable native MPD systemd user service ---
mpd_enabled:
  cmd.run:
    - name: systemctl --user enable --now mpd.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - require:
      - file: mpd_config
      - file: mpd_directories
      - cmd: music_mount
      - cmd: mpd_fifo
    - onlyif: pacman -Q mpd
    - unless: systemctl --user is-active mpd.service

# --- Deploy mpdas config via gopass ---
mpdas_config:
  cmd.run:
    - name: |
        set -eo pipefail
        USER=$(gopass show -o lastfm/username)
        PASS=$(gopass show -o lastfm/password)
        cat > {{ home }}/.config/mpdasrc << EOF
        host = localhost
        port = 6600
        service = lastfm
        username = ${USER}
        password = ${PASS}
        EOF
        chmod 600 {{ home }}/.config/mpdasrc
    - runas: {{ user }}
    - creates: {{ home }}/.config/mpdasrc

# --- Deploy mpdas systemd user service ---
mpdas_service_file:
  file.managed:
    - name: {{ home }}/.config/systemd/user/mpdas.service
    - source: salt://dotfiles/dot_config/systemd/user/mpdas.service
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - makedirs: True

# --- Enable mpd companion services (mpdris2 + mpdas) in a single systemctl call ---
mpd_companion_services:
  cmd.run:
    - name: |
        {% raw %}
        services=()
        pacman -Q mpdris2 >/dev/null 2>&1 && ! systemctl --user is-enabled mpDris2.service 2>/dev/null && services+=(mpDris2.service)
        pacman -Q mpdas >/dev/null 2>&1 && ! systemctl --user is-enabled mpdas.service 2>/dev/null && services+=(mpdas.service)
        if [ ${#services[@]} -gt 0 ]; then
          systemctl --user enable --now "${services[@]}"
        fi
        {% endraw %}
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: {{ host.runtime_dir }}
      - DBUS_SESSION_BUS_ADDRESS: unix:path={{ host.runtime_dir }}/bus
    - shell: /bin/bash
    - require:
      - cmd: mpd_enabled
      - cmd: mpdas_config
      - file: mpdas_service_file
    - unless: |
        (! pacman -Q mpdris2 >/dev/null 2>&1 || systemctl --user is-enabled mpDris2.service 2>/dev/null) &&
        (! pacman -Q mpdas >/dev/null 2>&1 || systemctl --user is-enabled mpdas.service 2>/dev/null)
{% endif %}
