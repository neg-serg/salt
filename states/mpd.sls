{% from '_imports.jinja' import host, user, home, pkg_list %}
{% from '_macros_service.jinja' import ensure_dir, user_service_file, user_service_enable %}
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
{{ ensure_dir('rmpc_config_dir', home ~ '/.config/rmpc') }}

rmpc_config:
  file.recurse:
    - name: {{ home }}/.config/rmpc
    - source: salt://dotfiles/dot_config/rmpc
    - user: {{ user }}
    - group: {{ user }}

# wiremix needs custom clang args for bindgen
install_wiremix:
  cmd.run:
    - name: BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/clang/21/include" cargo install wiremix
    - runas: {{ user }}
    - creates: {{ home }}/.local/share/cargo/bin/wiremix
    - retry:
        attempts: 3
        interval: 10

# --- MPD FIFO for visualizers (cava, etc.) ---
mpd_fifo:
  cmd.run:
    - name: |
        if [ ! -p /tmp/mpd.fifo ]; then
            mkfifo /tmp/mpd.fifo
            chmod 0666 /tmp/mpd.fifo
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
{{ user_service_enable('mpd_enabled', start_now=['mpd.service'], check='active', onlyif='rg -qx mpd ' ~ pkg_list, requires=['file: mpd_config', 'file: mpd_directories', 'cmd: music_mount', 'cmd: mpd_fifo']) }}

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
        chmod 0600 {{ home }}/.config/mpdasrc
    - runas: {{ user }}
    - creates: {{ home }}/.config/mpdasrc

# --- Deploy mpdas systemd user service ---
{{ user_service_file('mpdas_service_file', 'mpdas.service', source='salt://dotfiles/dot_config/systemd/user/mpdas.service') }}

# --- Enable mpd companion services (mpdris2 + mpdas) in a single systemctl call ---
mpd_companion_services:
  cmd.run:
    - name: |
        C={{ pkg_list }}
        {% raw %}
        services=()
        rg -qx 'mpdris2' "$C" && ! systemctl --user is-enabled mpDris2.service 2>/dev/null && services+=(mpDris2.service)
        rg -qx 'mpdas' "$C" && ! systemctl --user is-enabled mpdas.service 2>/dev/null && services+=(mpdas.service)
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
        (! rg -qx 'mpdris2' {{ pkg_list }} || systemctl --user is-enabled mpDris2.service 2>/dev/null) &&
        (! rg -qx 'mpdas' {{ pkg_list }} || systemctl --user is-enabled mpdas.service 2>/dev/null)
{% endif %}
