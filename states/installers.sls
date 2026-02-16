{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import curl_bin, github_tar, github_release, pip_pkg, cargo_pkg, curl_extract_tar, curl_extract_zip, run_with_error_context %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set user = host.user %}
{% set home = host.home %}

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

# --- GitHub releases (with tag fetching) ---
{% for name, opts in tools.github_release.items() %}
{{ github_release(name, opts.repo, opts.asset, bin=opts.get('bin'), format=opts.get('format', 'bin'), strip_v=opts.get('strip_v', False)) }}
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
{{ curl_extract_tar(name, opts.url, opts.binary_pattern, fetch_tag=opts.get('fetch_tag', False), binaries=opts.get('binaries')) }}
{% endfor %}

# ===========================================================================
# Custom installs (not data-driven — unique logic or version interpolation)
# ===========================================================================

# --- Shell frameworks ---
install_zi:
  cmd.run:
    - name: |
        set -eo pipefail
        export ZI_HOME="$HOME/.config/zi"
        mkdir -p "$ZI_HOME"
        git clone https://github.com/z-shell/zi.git "$ZI_HOME/bin"
    - runas: {{ user }}
    - creates: {{ home }}/.config/zi/bin/zi.zsh

install_oh_my_posh:
  cmd.run:
    - name: curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    - runas: {{ user }}
    - creates: {{ home }}/.local/bin/oh-my-posh

# --- Hyprland tools (multi-binary) ---
install_hyprevents:
  cmd.run:
    - name: |
        set -eo pipefail
        tmpdir=$(mktemp -d)
        cd "$tmpdir"
        curl -fsSL https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz | tar xz --strip-components=1
        install -Dm755 hyprevents event_handler event_loader -t ~/.local/bin/
        rm -rf "$tmpdir"
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/bin/hyprevents

# --- Image upscaling (version-pinned) ---
{{ curl_extract_zip('realesrgan', 'https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases/download/v' ~ ver.realesrgan ~ '/realesrgan-ncnn-vulkan-v' ~ ver.realesrgan ~ '-ubuntu.zip', 'realesrgan-ncnn-vulkan-v' ~ ver.realesrgan ~ '-ubuntu', binaries=['realesrgan-ncnn-vulkan'], chmod=True) }}

# --- Audio analysis (version-pinned) ---
{% call run_with_error_context('install_essentia_extractor', creates=home ~ '/.local/bin/essentia_streaming_extractor_music') %}
step "Downloading Essentia streaming extractor"
curl -fsSL https://data.metabrainz.org/pub/musicbrainz/acousticbrainz/extractors/essentia-extractor-v{{ ver.essentia }}-linux-x86_64.tar.gz -o /tmp/essentia.tar.gz
step "Extracting archive"
tar -xzf /tmp/essentia.tar.gz -C /tmp
step "Installing to ~/.local/bin/"
install -m755 /tmp/streaming_extractor_music ~/.local/bin/essentia_streaming_extractor_music
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

# --- cargo: tailray (needs dbus headers, has onlyif guards) ---
install_tailray:
  cmd.run:
    - name: cargo install --git https://github.com/NotAShelf/tailray
    - runas: {{ user }}
    - creates: {{ home }}/.local/share/cargo/bin/tailray
    - onlyif:
      - pkg-config --exists dbus-1
      - command -v cargo

# --- Script installs ---
install_dool:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/scottchiefbaker/dool.git /tmp/dool
        cp /tmp/dool/dool ~/.local/bin/
        chmod +x ~/.local/bin/dool
        rm -rf /tmp/dool
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/bin/dool

install_qmk_udev_rules:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules -o /etc/udev/rules.d/50-qmk.rules && udevadm control --reload-rules
    - creates: /etc/udev/rules.d/50-qmk.rules

# --- blesh (Bash Line Editor) ---
install_blesh:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz -o /tmp/blesh.tar.xz
        tar -xJf /tmp/blesh.tar.xz -C ~/.local/share/ --strip-components=1
        rm -f /tmp/blesh.tar.xz
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/share/ble.sh

# --- MPV scripts (installed per-user) ---
install_mpv_scripts:
  cmd.run:
    - name: |
        set -eo pipefail
        SCRIPTS_DIR=~/.config/mpv/scripts
        mkdir -p "$SCRIPTS_DIR"
        # uosc (modern UI)
        TAG=$(curl -fsSIL -o /dev/null -w '%{url_effective}' https://github.com/tomasklaen/uosc/releases/latest | grep -oP '[^/]+$')
        curl -fsSL "https://github.com/tomasklaen/uosc/releases/download/${TAG}/uosc.zip" -o /tmp/uosc.zip
        unzip -qo /tmp/uosc.zip -d ~/.config/mpv/
        rm /tmp/uosc.zip
        # thumbfast
        curl -fsSL https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua -o "$SCRIPTS_DIR/thumbfast.lua"
        # sponsorblock
        curl -fsSL https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock.lua -o "$SCRIPTS_DIR/sponsorblock.lua"
        # quality-menu
        curl -fsSL https://raw.githubusercontent.com/christoph-heinrich/mpv-quality-menu/master/quality-menu.lua -o "$SCRIPTS_DIR/quality-menu.lua"
        # mpris
        TAG=$(curl -fsSIL -o /dev/null -w '%{url_effective}' https://github.com/hoyon/mpv-mpris/releases/latest | grep -oP '[^/]+$')
        curl -fsSL "https://github.com/hoyon/mpv-mpris/releases/download/${TAG}/mpris.so" -o "$SCRIPTS_DIR/mpris.so"
        # cutter
        curl -fsSL https://raw.githubusercontent.com/rushmj/mpv-video-cutter/master/cutter.lua -o "$SCRIPTS_DIR/cutter.lua"
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.config/mpv/scripts/thumbfast.lua
