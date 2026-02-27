{% from '_imports.jinja' import user, home, retry_attempts, retry_interval, ver_dir %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_install.jinja' import curl_bin, pip_pkg, cargo_pkg, curl_extract_tar, curl_extract_zip, git_clone_deploy %}
{% from '_macros_github.jinja' import github_tar, github_release_to %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}

# ===========================================================================
# Data-driven installs (definitions in data/installers.yaml)
# ===========================================================================

# --- Direct binary downloads to ~/.local/bin/ ---
{% for name, raw in tools.curl_bin.items() %}
{% set _v = ver.get(name | replace('-', '_'), '') %}
{% if raw is mapping %}
{% set resolved_url = raw.url | replace('${VER}', _v) %}
{{ curl_bin(name, resolved_url, version=_v if _v else None, hash=raw.get('hash')) }}
{% else %}
{% set resolved_url = raw | replace('${VER}', _v) %}
{{ curl_bin(name, resolved_url, version=_v if _v else None) }}
{% endif %}
{% endfor %}

# --- GitHub tar.gz archives ---
{% for name, raw in tools.github_tar.items() %}
{% set _v = ver.get(name | replace('-', '_'), '') %}
{% if raw is mapping %}
{% set resolved_url = raw.url | replace('${VER}', _v) %}
{{ github_tar(name, resolved_url, version=_v if _v else None, hash=raw.get('hash')) }}
{% else %}
{% set resolved_url = raw | replace('${VER}', _v) %}
{{ github_tar(name, resolved_url, version=_v if _v else None) }}
{% endif %}
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
{% set _v = ver.get(name, '') %}
{% set resolved_url = opts.url | replace('${VER}', _v) %}
{{ curl_extract_zip(name, resolved_url, opts.binary_path, binaries=opts.get('binaries'), chmod=opts.get('chmod', False), hash=opts.get('hash'), version=_v if _v else None) }}
{% endfor %}

# --- tar.gz archive extractions ---
{% for name, opts in tools.get('curl_extract_tar', {}).items() %}
{% set _v = ver.get(name, '') %}
{% set resolved_url = opts.url | replace('${VER}', _v) %}
{{ curl_extract_tar(name, resolved_url, binary_pattern=opts.binary_pattern, bin=opts.get('bin'), hash=opts.get('hash'), version=_v if _v else None) }}
{% endfor %}

# ===========================================================================
# Custom installs (not data-driven — unique logic or version interpolation)
# ===========================================================================

# --- Shell frameworks ---
{{ git_clone_deploy('zi', 'https://github.com/z-shell/zi.git', '~/.config/zi/bin', creates=home ~ '/.config/zi/bin/zi.zsh', user=user, home=home) }}

# --- Hyprland tools (multi-binary) ---
{{ curl_extract_tar('hyprevents', 'https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz', 'hyprevents-master', binaries=['hyprevents', 'event_handler', 'event_loader'], chmod=True) }}

# --- pip: dr14_tmeter (custom git install, needs GIT_CONFIG_GLOBAL override) ---
{{ pip_pkg('dr14_tmeter', pkg='git+https://github.com/simon-r/dr14_t.meter.git', env='GIT_CONFIG_GLOBAL=/dev/null') }}

# --- cargo: tailray (needs dbus headers, has onlyif guards) ---
{{ cargo_pkg('tailray', git='https://github.com/NotAShelf/tailray', onlyif=['pkg-config --exists dbus-1', 'command -v cargo']) }}

qmk_udev_rules:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules -o /etc/udev/rules.d/50-qmk.rules && udevadm control --reload-rules
    - creates: /etc/udev/rules.d/50-qmk.rules
    - parallel: True
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

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
    - parallel: True
{% endfor %}

# cutter.lua writes time_pairs.txt to scripts/ by default; mpv tries to load it as a script
cutter_lua_output_path:
  file.replace:
    - name: {{ mpv_scripts_dir }}/cutter.lua
    - pattern: "output_file='~/.config/mpv/scripts/time_pairs.txt'"
    - repl: "output_file='~/.config/mpv/time_pairs.txt'"
    - require:
      - cmd: mpv_script_cutter_lua

{% for filename, opts in mpv.github_release.items() %}
{% set mpv_tag = ver.get(opts.repo.split('/')[1] | replace('-', '_'), '') %}
{{ github_release_to('mpv_script_' ~ (filename | replace('.', '_') | replace('-', '_')), filename, opts.repo, opts.asset, mpv_scripts_dir, tag=mpv_tag if mpv_tag else None, version=mpv_tag if mpv_tag else None, require='mpv_scripts_dir') }}
{% endfor %}

# mpris.so: v1.2+ is source-only; build with meson (v1.1 binary was libavformat.so.58, system has .so.62)
mpv_script_mpris_so:
  cmd.run:
    - name: |
        set -eo pipefail
        _td=$(mktemp -d)
        trap 'rm -rf "$_td"' EXIT
        git clone --depth 1 --branch {{ ver.mpv_mpris }} https://github.com/hoyon/mpv-mpris "$_td"
        cd "$_td"
        meson setup build
        meson compile -C build
        install -m 0644 build/mpris.so {{ mpv_scripts_dir }}/mpris.so
        mkdir -p {{ ver_dir }} && echo '{{ ver.mpv_mpris }}' > {{ ver_dir }}/mpris.so
    - runas: {{ user }}
    - shell: /bin/bash
    - unless: test -f {{ mpv_scripts_dir }}/mpris.so && test -f {{ ver_dir }}/mpris.so && rg -qx '{{ ver.mpv_mpris }}' {{ ver_dir }}/mpris.so
    - require:
      - file: mpv_scripts_dir
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

{% for name, opts in mpv.github_release_zip.items() %}
{% set _v = ver.get(name, '') %}
{{ github_release_to('mpv_plugin_' ~ name, name, opts.repo, opts.asset, opts.dest, format='zip', tag=_v if _v else None, version=_v if _v else None, creates=mpv_scripts_dir ~ '/' ~ name, require='mpv_scripts_dir') }}
{% endfor %}
