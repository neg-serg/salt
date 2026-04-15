{% from '_imports.jinja' import user, home, retry_attempts, retry_interval %}
{% from '_macros_install.jinja' import cargo_pkg, curl_bin, curl_extract_tar, curl_extract_zip, git_clone_build, git_clone_deploy, go_pkg, http_file, install_catalog, pip_pkg %}
{% from '_macros_pkg.jinja' import paru_install %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}

# ===========================================================================
# Data-driven fallback installs (definitions in data/installers.yaml)
# Use only when no official/AUR package is suitable.
# ===========================================================================

# --- Direct binary downloads to ~/.local/bin/ ---
{{ install_catalog(tools.curl_bin, ver, 'curl_bin') }}

# --- GitHub tar.gz archives ---
{{ install_catalog(tools.github_tar, ver, 'curl_extract_tar') }}

# --- pip installs (pipx) ---
{% for name, opts in tools.pip_pkg.items() %}
{{ pip_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

# --- cargo installs ---
{% for name, opts in tools.cargo_pkg.items() %}
{{ cargo_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin'), git=opts.get('git')) }}
{% endfor %}

# --- go installs ---
{% for name, opts in tools.get('go_pkg', {}).items() %}
{{ go_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

# --- ZIP archive extractions ---
{{ install_catalog(tools.curl_extract_zip, ver, 'curl_extract_zip') }}

# --- tar.gz archive extractions ---
{{ install_catalog(tools.get('curl_extract_tar', {}), ver, 'curl_extract_tar', exclude=['essentia']) }}

# ===========================================================================
# AUR package installs (migrated from manual downloads)
# ===========================================================================
{{ paru_install('tdl', 'tdl-bin') }}
# Modern TUI man page viewer (replaces man-db with mandoc)
{{ paru_install('qman', 'qman') }}

# One-time cleanup: remove old manually-installed binary
tdl_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/tdl
    - onlyif: test -f {{ home }}/.local/bin/tdl

# ===========================================================================
# Custom installs (not data-driven — unique logic or version interpolation)
# ===========================================================================

# --- Shell frameworks ---
{{ git_clone_deploy('zi', 'https://github.com/z-shell/zi.git', '~/.config/zi/bin', creates=home ~ '/.config/zi/bin/zi.zsh', user=user, home=home) }}

# --- Hyprland tools (multi-binary) ---
{{ curl_extract_tar('hyprevents', 'https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz', 'hyprevents-master', binaries=['hyprevents', 'event_handler', 'event_loader'], chmod=True) }}

# --- pip: dr14_tmeter (custom git install, needs GIT_CONFIG_GLOBAL override) ---
{{ pip_pkg('dr14_tmeter', pkg='git+https://github.com/simon-r/dr14_t.meter.git', env='GIT_CONFIG_GLOBAL=/dev/null') }}

# tailray: migrated to PKGBUILD (build/pkgbuilds/tailray/)

{{ http_file('qmk_udev_rules', 'https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules', '/etc/udev/rules.d/50-qmk.rules', mode='0644', user=None, parallel=False) }}

qmk_udev_rules_reload:
  cmd.run:
    - name: udevadm control --reload-rules
    - onlyif: command -v udevadm >/dev/null 2>&1
    - onchanges:
      - cmd: qmk_udev_rules

# --- termcell (terminal CSV editor) ---
{{ git_clone_deploy('termcell', 'https://github.com/xqtr/termcell.git', '~/.local/share/termcell', creates=home ~ '/.local/share/termcell/termcell.py', user=user, home=home) }}

termcell_wrapper:
  file.managed:
    - name: {{ home }}/.local/bin/termcell
    - contents: |
        #!/bin/bash
        exec python3 ~/.local/share/termcell/termcell.py "$@"
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - cmd: install_termcell

# --- fzf-navigator (sourced shell script for filesystem navigation) ---
{{ http_file('fzf_navigator', 'https://raw.githubusercontent.com/benward2301/fzf-navigator/main/fzf-navigator.sh', home ~ '/.config/fzf-navigator.sh', user=user) }}

# --- nface (terminal ASCII webcam via ncurses/v4l2) ---
{{ git_clone_build('nface', 'https://github.com/tomScheers/nFace.git', 'make', 'bin/nface') }}

# --- termmark (terminal Markdown renderer) ---
{{ git_clone_build('termmark', 'https://github.com/ishanawal/TermMark.git', 'cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && make -C build', 'build/termmark') }}

# --- blesh (Bash Line Editor) ---
{{ curl_extract_tar('blesh', 'https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz', archive_ext='tar.xz', dest='~/.local/share', strip_components=1, creates=home ~ '/.local/share/ble.sh', user=user, home=home) }}
