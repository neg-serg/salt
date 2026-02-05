# MPD Container Deployment
# Salt state for deploying MPD as a Podman container with systemd integration

{% set user = 'neg' %}
{% set home = '/var/home/' ~ user %}
{% set containers_src = '/var/home/neg/src/salt/containers/mpd' %}

# Ensure required directories exist
mpd_directories:
  file.directory:
    - names:
      - {{ home }}/.local/share/mpd
      - {{ home }}/.config/mpd/playlists
      - {{ home }}/.config/containers/systemd
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

# Create FIFO for visualizers
mpd_fifo:
  cmd.run:
    - name: |
        if [ ! -p /tmp/mpd.fifo ]; then
            mkfifo /tmp/mpd.fifo
            chmod 666 /tmp/mpd.fifo
        fi
    - runas: {{ user }}
    - unless: test -p /tmp/mpd.fifo

# Build MPD container image
mpd_container_build:
  cmd.run:
    - name: podman build -t localhost/mpd:latest {{ containers_src }}
    - runas: {{ user }}
    - unless: podman image exists localhost/mpd:latest

# Deploy quadlet file for systemd integration
mpd_quadlet:
  file.managed:
    - name: {{ home }}/.config/containers/systemd/mpd.container
    - source: salt://containers/mpd/mpd.container
    - user: {{ user }}
    - group: {{ user }}
    - mode: 644
    - require:
      - file: mpd_directories

# Reload systemd user daemon
mpd_systemd_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - onchanges:
      - file: mpd_quadlet

# Enable and start MPD service
mpd_service_enable:
  cmd.run:
    - name: systemctl --user enable --now mpd.service
    - runas: {{ user }}
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - require:
      - cmd: mpd_container_build
      - cmd: mpd_systemd_reload
    - unless: systemctl --user is-active mpd.service
