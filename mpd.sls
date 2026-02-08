# MPD Native Deployment
# Salt state for setting up MPD with systemd user service and pipewire output

{% set user = 'neg' %}
{% set home = '/var/home/' ~ user %}

# --- Bind mount for music directory ---
music_mount_point:
  file.directory:
    - name: {{ home }}/music
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

music_fstab_entry:
  file.append:
    - name: /etc/fstab
    - text: |

        # Bind mounts for user directories (migrated from NixOS)
        /var/mnt/one/music {{ home }}/music none rbind,nofail,x-systemd.automount 0 0
    - unless: grep -q '{{ home }}/music' /etc/fstab

music_mount:
  cmd.run:
    - name: mount {{ home }}/music || true
    - unless: mountpoint -q {{ home }}/music
    - require:
      - file: music_fstab_entry
      - file: music_mount_point

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

# --- Build ncpamixer from source ---
ncpamixer_clone:
  git.cloned:
    - name: https://github.com/fulhax/ncpamixer.git
    - target: /tmp/ncpamixer
    - user: {{ user }}
    - unless: test -f {{ home }}/.local/bin/ncpamixer

ncpamixer_build:
  cmd.run:
    - name: cd /tmp/ncpamixer && rm -rf build && make RELEASE=1
    - runas: {{ user }}
    - require:
      - git: ncpamixer_clone
    - unless: test -f {{ home }}/.local/bin/ncpamixer

ncpamixer_install:
  file.managed:
    - name: {{ home }}/.local/bin/ncpamixer
    - source: /tmp/ncpamixer/build/ncpamixer
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - cmd: ncpamixer_build
    - unless: test -f {{ home }}/.local/bin/ncpamixer

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
    - unless: systemctl --user is-active mpd.service

# --- Enable mpdris2 (MPRIS2 bridge) ---
mpdris2_service:
  cmd.run:
    - name: systemctl --user enable --now mpdris2.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - require:
      - cmd: mpd_service
    - unless: systemctl --user is-enabled mpdris2.service

# --- Enable rescrobbled (MPRIS scrobbler) ---
rescrobbled_service:
  cmd.run:
    - name: systemctl --user enable --now rescrobbled.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - require:
      - cmd: mpd_service
    - unless: systemctl --user is-enabled rescrobbled.service
