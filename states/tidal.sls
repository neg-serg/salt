{% from '_imports.jinja' import host, user, home, pkg_list, retry_attempts, retry_interval %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_service.jinja' import ensure_dir %}
# TidalCycles live coding: SuperCollider + SuperDirt + GHCi/Tidal
# Signal: nvim (.tidal) → GHCi REPL → OSC :57120 → scsynth/SuperDirt → PipeWire
{% if host.features.tidal %}

# --- Packages: audio engine + Haskell runtime ---
{% for pkg in ['supercollider', 'sc3-plugins', 'ghc', 'haskell-tidal'] %}
{{ pacman_install(pkg, pkg) }}
{% endfor %}

# --- SuperCollider config directory ---
{{ ensure_dir('supercollider_config_dir', home ~ '/.config/SuperCollider') }}

# --- SuperDirt quark install (downloads ~2GB Dirt-Samples from Codeberg) ---
superdirt_quark_install:
  cmd.script:
    - source: salt://scripts/superdirt-install.sh
    - shell: /bin/bash
    - runas: {{ user }}
    - creates: {{ home }}/.local/share/SuperCollider/downloaded-quarks/SuperDirt
    - timeout: 1200
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: install_supercollider

# --- startup.scd: auto-boot SuperDirt on sclang launch ---
superdirt_startup_config:
  file.managed:
    - name: {{ home }}/.config/SuperCollider/startup.scd
    - source: salt://configs/supercollider-startup.scd
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - require:
      - file: supercollider_config_dir
      - cmd: superdirt_quark_install

{% endif %}
