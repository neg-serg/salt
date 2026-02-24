{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_install.jinja' import curl_bin, pip_pkg, cargo_pkg, curl_extract_tar, curl_extract_zip, git_clone_deploy %}
{% from '_macros_github.jinja' import github_tar, github_release_to %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}

# ===========================================================================
# Data-driven installs (definitions in data/installers.yaml)
# ===========================================================================

# --- Direct binary downloads to ~/.local/bin/ ---
{% for name, url in tools.curl_bin.items() %}
{% set resolved_url = url | replace('${VER}', ver.get(name | replace('-', '_'), '')) %}
{{ curl_bin(name, resolved_url) }}
{% endfor %}

# --- GitHub tar.gz archives ---
{% for name, url in tools.github_tar.items() %}
{% set resolved_url = url | replace('${VER}', ver.get(name | replace('-', '_'), '')) %}
{{ github_tar(name, resolved_url) }}
{% endfor %}

# --- pip installs (pipx) ---
{% for name, opts in tools.pip_pkg.items() %}
{{ pip_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

# --- cargo installs ---
{% for name, opts in tools.cargo_pkg.items() %}
{{ cargo_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin'), git=opts.get('git')) }}
{% endfor %}

# --- ZIP archive extractions ---
{% for name, opts in tools.curl_extract_zip.items() %}
{% set resolved_url = opts.url | replace('${VER}', ver.get(name, '')) %}
{{ curl_extract_zip(name, resolved_url, opts.binary_path, binaries=opts.get('binaries'), chmod=opts.get('chmod', False)) }}
{% endfor %}

# --- tar.gz archive extractions ---
{% for name, opts in tools.get('curl_extract_tar', {}).items() %}
{% set resolved_url = opts.url | replace('${VER}', ver.get(name, '')) %}
{{ curl_extract_tar(name, resolved_url, binary_pattern=opts.binary_pattern, bin=opts.get('bin')) }}
{% endfor %}

# ===========================================================================
# Custom installs (not data-driven — unique logic or version interpolation)
# ===========================================================================

# --- Shell frameworks ---
{{ git_clone_deploy('zi', 'https://github.com/z-shell/zi.git', '~/.config/zi/bin', creates=home ~ '/.config/zi/bin/zi.zsh', user=user, home=home) }}

# --- Hyprland tools (multi-binary) ---
{{ curl_extract_tar('hyprevents', 'https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz', 'hyprevents-master', binaries=['hyprevents', 'event_handler', 'event_loader'], chmod=True) }}

# --- pip: dr14_tmeter (custom git install, not standard pip_pkg) ---
install_dr14_tmeter:
  cmd.run:
    - name: GIT_CONFIG_GLOBAL=/dev/null pipx install git+https://github.com/simon-r/dr14_t.meter.git
    - runas: {{ user }}
    - creates: {{ home }}/.local/bin/dr14_tmeter
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

# --- cargo: tailray (needs dbus headers, has onlyif guards) ---
install_tailray:
  cmd.run:
    - name: cargo install --git https://github.com/NotAShelf/tailray
    - runas: {{ user }}
    - creates: {{ home }}/.local/share/cargo/bin/tailray
    - onlyif:
      - pkg-config --exists dbus-1
      - command -v cargo
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

install_qmk_udev_rules:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules -o /etc/udev/rules.d/50-qmk.rules && udevadm control --reload-rules
    - creates: /etc/udev/rules.d/50-qmk.rules

# --- blesh (Bash Line Editor) ---
{{ curl_extract_tar('blesh', 'https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz', archive_ext='tar.xz', dest='~/.local/share', strip_components=1, creates=home ~ '/.local/share/ble.sh', user=user, home=home) }}

# --- MPV scripts (installed per-user, definitions in data/mpv_scripts.yaml) ---
{% import_yaml 'data/mpv_scripts.yaml' as mpv %}
{% set mpv_scripts_dir = home ~ '/.config/mpv/scripts' %}

{{ ensure_dir('mpv_scripts_dir', mpv_scripts_dir) }}

{% for filename, url in mpv.raw.items() %}
mpv_script_{{ filename | replace('.', '_') | replace('-', '_') }}:
  cmd.run:
    - name: curl -fsSL '{{ url }}' -o '{{ mpv_scripts_dir }}/{{ filename }}'
    - runas: {{ user }}
    - creates: {{ mpv_scripts_dir }}/{{ filename }}
    - require:
      - file: mpv_scripts_dir
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
{% endfor %}

{% for filename, opts in mpv.github_release.items() %}
{% set mpv_tag = ver.get(opts.repo.split('/')[1] | replace('-', '_'), '') %}
{{ github_release_to('mpv_script_' ~ (filename | replace('.', '_') | replace('-', '_')), filename, opts.repo, opts.asset, mpv_scripts_dir, tag=mpv_tag if mpv_tag else None, require='mpv_scripts_dir') }}
{% endfor %}

{% for name, opts in mpv.github_release_zip.items() %}
{{ github_release_to('mpv_plugin_' ~ name, name, opts.repo, opts.asset, opts.dest, format='zip', tag=ver.get(name, '') if ver.get(name, '') else None, creates=mpv_scripts_dir ~ '/' ~ name, require='mpv_scripts_dir') }}
{% endfor %}
