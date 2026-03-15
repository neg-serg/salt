{% from '_imports.jinja' import host, user, home, pkg_list, gopass_secret %}
{% from '_macros_install.jinja' import cargo_pkg %}
{% from '_macros_service.jinja' import user_service_file, user_service_enable %}
# MPD Native Deployment
# Salt state for setting up MPD with systemd user service and pipewire output
include:
  - bind_mounts

{% set mpdris2_installed = salt['file.search'](pkg_list, '^mpdris2$', flags='m') %}
{% set mpdas_installed = salt['file.search'](pkg_list, '^mpdas$', flags='m') %}
{%- set companion_units = [] -%}
{%- if mpdris2_installed -%}
{%-   do companion_units.append('mpDris2.service') -%}
{%- endif -%}
{%- if mpdas_installed -%}
{%-   do companion_units.append('mpdas.service') -%}
{%- endif -%}
{%- set companion_reqs = ['cmd: mpd_enabled', 'file: mpdas_config'] -%}
{%- if mpdris2_installed -%}
{%-   do companion_reqs.append('cmd: mpdris2_user_service_daemon_reload') -%}
{%- endif -%}
{%- if mpdas_installed -%}
{%-   do companion_reqs.append('file: mpdas_service_file') -%}
{%-   do companion_reqs.append('cmd: mpdas_service_file_daemon_reload') -%}
{%- endif -%}

# --- MPD directories ---
mpd_directories:
  file.directory:
    - names:
      - {{ home }}/.local/share/mpd
      - {{ home }}/.config/mpd/playlists
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

# wiremix needs custom clang args for bindgen
{{ cargo_pkg('wiremix', env='BINDGEN_EXTRA_CLANG_ARGS="-I/usr/lib/clang/$(ls /usr/lib/clang/ | sort -V | tail -1)/include"') }}

# --- MPD FIFO for visualizers (cava, etc.) ---
# tmpfiles.d ensures the FIFO is recreated on every boot automatically
mpd_fifo_conf:
  file.managed:
    - name: /etc/tmpfiles.d/mpd-fifo.conf
    - contents: "p /tmp/mpd.fifo 0660 {{ user }} {{ user }} -"
    - mode: '0644'

mpd_fifo:
  cmd.run:
    - name: systemd-tmpfiles --create /etc/tmpfiles.d/mpd-fifo.conf
    - unless: test -p /tmp/mpd.fifo
    - require:
      - file: mpd_fifo_conf

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

# --- Deploy mpdas config via gopass (graceful fallback to empty values) ---
{%- set lastfm_user = gopass_secret('lastfm/username') | trim %}
{%- set lastfm_pass = gopass_secret('lastfm/password') | trim %}
mpdas_config:
  file.managed:
    - name: {{ home }}/.config/mpdasrc
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - replace: False
    - contents: |
        host = localhost
        port = 6600
        service = lastfm
        username = {{ lastfm_user }}
        password = {{ lastfm_pass }}

# --- Deploy mpdas systemd user service ---
{{ user_service_file('mpdas_service_file', 'mpdas.service', source='salt://dotfiles/dot_config/systemd/user/mpdas.service') }}

{% if companion_units %}
{{ user_service_enable('mpd_companion_services', start_now=companion_units, check='active', requires=companion_reqs) }}
{% endif %}
