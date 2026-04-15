{% from '_imports.jinja' import user, home, retry_attempts, retry_interval %}
{% from '_macros_pkg.jinja' import paru_install %}
# TidalCycles live coding: SuperCollider + SuperDirt + GHCi/Tidal
# Signal: nvim (.tidal) → GHCi REPL → OSC :57120 → scsynth/SuperDirt → PipeWire
# Config files managed by chezmoi (dotfiles/dot_config/SuperCollider/)
# --- Packages: audio engine + Haskell runtime ---
{% for pkg in ['supercollider', 'sc3-plugins', 'ghc', 'haskell-tidal'] %}
{{ paru_install(pkg, pkg) }}
{% endfor %}

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
