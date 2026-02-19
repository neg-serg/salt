{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_install.jinja' import curl_bin, github_tar, github_release, pip_pkg, cargo_pkg, curl_extract_tar, curl_extract_zip, git_clone_deploy, run_with_error_context, github_release_to %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}

# ===========================================================================
# Data-driven installs (definitions in data/installers.yaml)
# ===========================================================================

# --- Direct binary downloads to ~/.local/bin/ ---
{% for name, url in tools.curl_bin.items() %}
{{ curl_bin(name, url) }}
{% endfor %}

# --- GitHub tar.gz archives ---
{% for name, url in tools.github_tar.items() %}
{{ github_tar(name, url) }}
{% endfor %}

# --- GitHub releases (binary downloads with tag fetching) ---
{% for name, opts in tools.github_release.items() %}
{{ github_release(name, opts.repo, opts.asset, bin=opts.get('bin'), strip_v=opts.get('strip_v', False)) }}
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
{{ curl_extract_zip(name, opts.url, opts.binary_path, binaries=opts.get('binaries'), chmod=opts.get('chmod', False)) }}
{% endfor %}

# --- tar.gz archive extractions ---
{% for name, opts in tools.curl_extract_tar.items() %}
{{ curl_extract_tar(name, opts.url, opts.binary_pattern, fetch_tag=opts.get('fetch_tag', False), strip_v=opts.get('strip_v', False), binaries=opts.get('binaries'), bin=opts.get('bin')) }}
{% endfor %}

# ===========================================================================
# Custom installs (not data-driven — unique logic or version interpolation)
# ===========================================================================

# --- Shell frameworks ---
{{ git_clone_deploy('zi', 'https://github.com/z-shell/zi.git', '~/.config/zi/bin', creates=home ~ '/.config/zi/bin/zi.zsh', user=user, home=home) }}

install_oh_my_posh:
  cmd.run:
    - name: curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    - runas: {{ user }}
    - creates: {{ home }}/.local/bin/oh-my-posh

# --- Hyprland tools (multi-binary) ---
{{ curl_extract_tar('hyprevents', 'https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz', 'hyprevents-master', binaries=['hyprevents', 'event_handler', 'event_loader'], chmod=True) }}

# --- Image upscaling (version-pinned) ---
{{ curl_extract_zip('realesrgan', 'https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases/download/v' ~ ver.realesrgan ~ '/realesrgan-ncnn-vulkan-v' ~ ver.realesrgan ~ '-ubuntu.zip', 'realesrgan-ncnn-vulkan-v' ~ ver.realesrgan ~ '-ubuntu', binaries=['realesrgan-ncnn-vulkan'], chmod=True) }}

# --- Audio analysis (version-pinned) ---
{% call run_with_error_context('install_essentia_extractor', creates=home ~ '/.local/bin/essentia_streaming_extractor_music') %}
step "Downloading Essentia streaming extractor"
curl -fsSL https://data.metabrainz.org/pub/musicbrainz/acousticbrainz/extractors/essentia-extractor-v{{ ver.essentia }}-linux-x86_64.tar.gz -o /tmp/essentia.tar.gz
step "Extracting archive"
tar -xzf /tmp/essentia.tar.gz -C /tmp
step "Installing to ~/.local/bin/"
install -m 0755 /tmp/streaming_extractor_music ~/.local/bin/essentia_streaming_extractor_music
step "Cleaning up"
rm -f /tmp/essentia.tar.gz
success "Essentia streaming extractor installed"
{%- endcall %}

# --- pip: dr14_tmeter (custom git install, not standard pip_pkg) ---
install_dr14_tmeter:
  cmd.run:
    - name: GIT_CONFIG_GLOBAL=/dev/null pipx install git+https://github.com/simon-r/dr14_t.meter.git
    - runas: {{ user }}
    - creates: {{ home }}/.local/bin/dr14_tmeter
    - retry:
        attempts: 3
        interval: 10

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
        attempts: 3
        interval: 10

# --- Script installs ---
{{ git_clone_deploy('dool', 'https://github.com/scottchiefbaker/dool.git', '~/.local/bin', ['dool'], creates=home ~ '/.local/bin/dool', user=user, home=home) }}

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
        attempts: 3
        interval: 10
{% endfor %}

{% for filename, opts in mpv.github_release.items() %}
{{ github_release_to('mpv_script_' ~ (filename | replace('.', '_') | replace('-', '_')), filename, opts.repo, opts.asset, mpv_scripts_dir, require='mpv_scripts_dir') }}
{% endfor %}

{% for name, opts in mpv.github_release_zip.items() %}
{{ github_release_to('mpv_plugin_' ~ name, name, opts.repo, opts.asset, opts.dest, format='zip', creates=mpv_scripts_dir ~ '/' ~ name, require='mpv_scripts_dir') }}
{% endfor %}
