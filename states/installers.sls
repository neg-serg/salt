{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}
# CLI tool installers: binaries, pip, cargo, scripts
{% from '_macros.jinja' import curl_bin, github_tar, github_release, pip_pkg, cargo_pkg, curl_extract_tar, curl_extract_zip, run_with_error_context %}
{% set realesrgan_ver = '0.2.0' %}
{% set essentia_ver = '2.1_beta2' %}

# --- Neovim Python dependencies (nvr + pynvim) ---
{{ pip_pkg('neovim_python_deps', pkg='neovim-remote', bin='nvr') }}

install_zi:
  cmd.run:
    - name: |
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

{{ curl_bin('aliae', 'https://github.com/JanDeDobbeleer/aliae/releases/latest/download/aliae-linux-amd64') }}
{{ curl_bin('grimblast', 'https://raw.githubusercontent.com/hyprwm/contrib/main/grimblast/grimblast') }}

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

{{ curl_bin('hyprprop', 'https://raw.githubusercontent.com/vilari-mickopf/hyprprop/master/hyprprop') }}
{{ github_release('sops', 'getsops/sops', 'sops-${TAG}.linux.amd64') }}
{{ curl_bin('xdg-ninja', 'https://github.com/b3nj5m1n/xdg-ninja/releases/latest/download/xdgnj') }}
{{ github_release('rmpc', 'mierak/rmpc', 'rmpc-${TAG}-x86_64-unknown-linux-gnu.tar.gz', format='tar.gz') }}
{{ cargo_pkg('rustmission') }}
{{ pip_pkg('httpstat') }}
{{ curl_bin('ssh-to-age', 'https://github.com/Mic92/ssh-to-age/releases/latest/download/ssh-to-age.linux-amd64') }}
{{ curl_extract_zip('yazi', 'https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip', 'yazi-x86_64-unknown-linux-musl', binaries=['yazi', 'ya']) }}
{{ curl_bin('broot', 'https://dystroy.org/broot/download/x86_64-linux/broot') }}
{{ curl_extract_tar('nushell', 'https://github.com/nushell/nushell/releases/latest/download/nu-${TAG}-x86_64-unknown-linux-musl.tar.gz', 'nu-*-x86_64-unknown-linux-musl/nu*', fetch_tag=True, binaries=['nu', 'nu_plugin_*']) }}
{{ github_tar('eza', 'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz') }}
{{ github_release('television', 'alexpasmantier/television', 'tv-${TAG}-x86_64-unknown-linux-musl.tar.gz', bin='tv', format='tar.gz') }}

# --- GitHub binary downloads (remaining migration packages) ---
{{ curl_extract_zip('xray', 'https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip', 'xray', chmod=True) }}
{{ github_release('sing-box', 'SagerNet/sing-box', 'sing-box-${VER}-linux-amd64.tar.gz', format='tar.gz', strip_v=True) }}
{{ github_tar('tdl', 'https://github.com/iyear/tdl/releases/latest/download/tdl_Linux_64bit.tar.gz') }}
{{ github_tar('camilladsp', 'https://github.com/HEnquist/camilladsp/releases/latest/download/camilladsp-linux-amd64.tar.gz') }}
{{ github_tar('opencode', 'https://github.com/opencode-ai/opencode/releases/latest/download/opencode-linux-x86_64.tar.gz') }}
{{ cargo_pkg('adguardian') }}
{{ curl_extract_zip('realesrgan', 'https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases/download/v' ~ realesrgan_ver ~ '/realesrgan-ncnn-vulkan-v' ~ realesrgan_ver ~ '-ubuntu.zip', 'realesrgan-ncnn-vulkan-v' ~ realesrgan_ver ~ '-ubuntu', binaries=['realesrgan-ncnn-vulkan'], chmod=True) }}

{% call run_with_error_context('install_essentia_extractor', creates=home ~ '/.local/bin/essentia_streaming_extractor_music') %}
step "Downloading Essentia streaming extractor"
curl -fsSL https://data.metabrainz.org/pub/musicbrainz/acousticbrainz/extractors/essentia-extractor-v{{ essentia_ver }}-linux-x86_64.tar.gz -o /tmp/essentia.tar.gz
step "Extracting archive"
tar -xzf /tmp/essentia.tar.gz -C /tmp
step "Installing to ~/.local/bin/"
install -m755 /tmp/streaming_extractor_music ~/.local/bin/essentia_streaming_extractor_music
step "Cleaning up"
rm -f /tmp/essentia.tar.gz
success "Essentia streaming extractor installed"
{%- endcall %}

# --- pip installs ---
{{ pip_pkg('scdl') }}
install_dr14_tmeter:
  cmd.run:
    - name: GIT_CONFIG_GLOBAL=/dev/null pipx install git+https://github.com/simon-r/dr14_t.meter.git
    - runas: {{ user }}
    - creates: {{ home }}/.local/bin/dr14_tmeter
{{ pip_pkg('euporie') }}
{{ pip_pkg('faker') }}

# --- cargo installs ---
{{ cargo_pkg('handlr', pkg='handlr-regex') }}
{{ cargo_pkg('agg', git='https://github.com/asciinema/agg') }}
{{ cargo_pkg('rustnet', git='https://github.com/domcyrus/rustnet') }}

# NOTE: tailray needs dbus headers (libdbus-sys).
install_tailray:
  cmd.run:
    - name: cargo install --git https://github.com/NotAShelf/tailray
    - runas: {{ user }}
    - creates: {{ home }}/.local/share/cargo/bin/tailray
    - onlyif:
      - pkg-config --exists dbus-1
      - command -v cargo

{{ cargo_pkg('pzip', bin='pz') }}

# --- Script and file installs ---
{{ curl_bin('mpvc', 'https://raw.githubusercontent.com/lwilletts/mpvc/master/mpvc') }}
{{ curl_bin('rofi-systemd', 'https://raw.githubusercontent.com/IvanMalison/rofi-systemd/master/rofi-systemd') }}

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

{{ github_release('hishtory', 'ddworken/hishtory', 'hishtory-linux-amd64') }}
{{ cargo_pkg('iwmenu', git='https://github.com/e-tho/iwmenu') }}
{{ curl_bin('rofi-pass', 'https://raw.githubusercontent.com/carnager/rofi-pass/master/rofi-pass') }}

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
