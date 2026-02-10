# MPD Native Deployment
# Salt state for setting up MPD with systemd user service and pipewire output

include:
  - bind_mounts

{% set user = 'neg' %}
{% set home = '/var/home/' ~ user %}

# --- MPD directories ---
mpd_directories:
  file.directory:
    - names:
      - {{ home }}/.local/share/mpd
      - {{ home }}/.config/mpd/playlists
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

# --- Deploy zsh config with MPD variables ---
mpd_zsh_config_dir:
  file.directory:
    - name: {{ home }}/.config/zsh
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

zsh_env:
  file.managed:
    - name: {{ home }}/.config/zsh/.zshenv
    - source: salt://dotfiles/dot_config/zsh/dot_zshenv
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'

zsh_rc:
  file.managed:
    - name: {{ home }}/.config/zsh/.zshrc
    - source: salt://dotfiles/dot_config/zsh/dot_zshrc
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'

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

# --- Install cargo packages (rmpc, wiremix) ---
cargo_packages:
  cmd.run:
    - name: |
        export PATH="{{ home }}/.cargo/bin:$PATH"
        cargo install rmpc 2>/dev/null || true
        BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/clang/21/include" cargo install wiremix 2>/dev/null || true
    - runas: {{ user }}
    - env:
      - HOME: {{ home }}
    - unless: test -f {{ home }}/.cargo/bin/rmpc

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
mpd_service:
  cmd.run:
    - name: systemctl --user enable --now mpd.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - require:
      - file: mpd_config
      - file: mpd_directories
      - cmd: music_mount
      - cmd: mpd_fifo
    - onlyif: rpm -q mpd
    - unless: systemctl --user is-active mpd.service

# --- Enable mpdris2 (MPRIS2 bridge, RPM-shipped unit) ---
mpdris2_service:
  cmd.run:
    - name: systemctl --user enable --now mpDris2.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - require:
      - cmd: mpd_service
    - onlyif: rpm -q mpdris2
    - unless: systemctl --user is-enabled mpDris2.service

# --- Deploy mpdas config via gopass ---
mpdas_config:
  cmd.run:
    - name: |
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

mpdas_service:
  cmd.run:
    - name: systemctl --user enable --now mpdas.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - require:
      - cmd: mpdas_config
      - file: mpdas_service_file
      - cmd: mpd_service
    - onlyif: rpm -q mpdas
    - unless: systemctl --user is-enabled mpdas.service
