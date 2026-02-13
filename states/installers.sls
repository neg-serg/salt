# CLI tool installers: binaries, pip, cargo, scripts, themes
{% from '_macros.jinja' import curl_bin, github_tar, github_release, pip_pkg, cargo_pkg %}

# --- Neovim Python dependencies (nvr + pynvim) ---
{{ pip_pkg('neovim_python_deps', pkg='pynvim neovim-remote', bin='nvr') }}

install_zi:
  cmd.run:
    - name: |
        export ZI_HOME="$HOME/.config/zi"
        mkdir -p "$ZI_HOME"
        git clone https://github.com/z-shell/zi.git "$ZI_HOME/bin"
    - runas: neg
    - creates: /var/home/neg/.config/zi/bin/zi.zsh

install_oh_my_posh:
  cmd.run:
    - name: curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    - runas: neg
    - creates: /var/home/neg/.local/bin/oh-my-posh

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
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/hyprevents

{{ curl_bin('hyprprop', 'https://raw.githubusercontent.com/vilari-mickopf/hyprprop/master/hyprprop') }}

{{ github_release('sops', 'getsops/sops', 'sops-${TAG}.linux.amd64') }}

{{ curl_bin('xdg-ninja', 'https://github.com/b3nj5m1n/xdg-ninja/releases/latest/download/xdgnj') }}

{{ github_release('rmpc', 'mierak/rmpc', 'rmpc-${TAG}-x86_64-unknown-linux-gnu.tar.gz', format='tar.gz') }}

install_rustmission:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/intuis/rustmission/releases/download/v0.5.0/rustmission-x86_64-unknown-linux-gnu.tar.xz -o /tmp/rustmission.tar.xz
        tar -xJf /tmp/rustmission.tar.xz -C /tmp --strip-components=1 --wildcards '*/rustmission'
        mv /tmp/rustmission ~/.local/bin/
        rm -f /tmp/rustmission.tar.xz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/rustmission

{{ pip_pkg('httpstat') }}

{{ curl_bin('ssh-to-age', 'https://github.com/Mic92/ssh-to-age/releases/latest/download/ssh-to-age.linux-amd64') }}

install_yazi:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip -o /tmp/yazi.zip
        unzip -o /tmp/yazi.zip -d /tmp/yazi_extracted
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/
        mv /tmp/yazi_extracted/yazi-x86_64-unknown-linux-musl/ya ~/.local/bin/
        rm -rf /tmp/yazi.zip /tmp/yazi_extracted
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/yazi

{{ curl_bin('broot', 'https://dystroy.org/broot/download/x86_64-linux/broot') }}

install_nushell:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/nushell/nushell/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/nushell/nushell/releases/latest/download/nu-${TAG}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/nu.tar.gz
        tar -xzf /tmp/nu.tar.gz -C /tmp
        mv /tmp/nu-*-x86_64-unknown-linux-musl/nu* ~/.local/bin/
        rm -rf /tmp/nu.tar.gz /tmp/nu-*-x86_64-unknown-linux-musl
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/nu

{{ github_tar('eza', 'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz') }}

{{ github_release('television', 'alexpasmantier/television', 'tv-${TAG}-x86_64-unknown-linux-musl.tar.gz', bin='tv', format='tar.gz') }}

# --- GitHub binary downloads (remaining migration packages) ---
install_xray:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o /tmp/xray.zip
        unzip -o /tmp/xray.zip -d /tmp/xray
        mv /tmp/xray/xray ~/.local/bin/
        chmod +x ~/.local/bin/xray
        rm -rf /tmp/xray.zip /tmp/xray
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/xray

{{ github_release('sing-box', 'SagerNet/sing-box', 'sing-box-${VER}-linux-amd64.tar.gz', format='tar.gz', strip_v=True) }}

{{ github_tar('tdl', 'https://github.com/iyear/tdl/releases/latest/download/tdl_Linux_64bit.tar.gz') }}

{{ github_tar('camilladsp', 'https://github.com/HEnquist/camilladsp/releases/latest/download/camilladsp-linux-amd64.tar.gz') }}

{{ github_tar('opencode', 'https://github.com/opencode-ai/opencode/releases/latest/download/opencode-linux-x86_64.tar.gz') }}

{{ curl_bin('adguardian', 'https://github.com/Lissy93/AdGuardian-Term/releases/latest/download/adguardian-linux') }}

install_realesrgan:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL "https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases/download/v0.2.0/realesrgan-ncnn-vulkan-v0.2.0-ubuntu.zip" -o /tmp/realesrgan.zip
        unzip -o /tmp/realesrgan.zip -d /tmp/realesrgan
        mv /tmp/realesrgan/realesrgan-ncnn-vulkan-v0.2.0-ubuntu/realesrgan-ncnn-vulkan ~/.local/bin/
        chmod +x ~/.local/bin/realesrgan-ncnn-vulkan
        rm -rf /tmp/realesrgan.zip /tmp/realesrgan
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/realesrgan-ncnn-vulkan

install_essentia_extractor:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://data.metabrainz.org/pub/musicbrainz/acousticbrainz/extractors/essentia-extractor-v2.1_beta2-linux-x86_64.tar.gz -o /tmp/essentia.tar.gz
        tar -xzf /tmp/essentia.tar.gz -C /tmp
        mv /tmp/streaming_extractor_music ~/.local/bin/essentia_streaming_extractor_music
        chmod +x ~/.local/bin/essentia_streaming_extractor_music
        rm -rf /tmp/essentia.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/essentia_streaming_extractor_music

# --- pip installs ---
{{ pip_pkg('scdl') }}
{{ pip_pkg('dr14_tmeter', pkg='git+https://github.com/simon-r/dr14_t.meter.git') }}
{{ pip_pkg('euporie') }}

# --- cargo installs ---
{{ cargo_pkg('handlr', pkg='handlr-regex') }}
{{ cargo_pkg('agg', git='https://github.com/asciinema/agg') }}

# NOTE: tailray needs dbus-devel (libdbus-sys). May fail on first run
# if dbus-devel was just layered and not yet active (requires reboot).
install_tailray:
  cmd.run:
    - name: cargo install --git https://github.com/NotAShelf/tailray
    - runas: neg
    - creates: /var/home/neg/.local/share/cargo/bin/tailray
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
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/dool

install_qmk_udev_rules:
  cmd.run:
    - name: curl -fsSL https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules -o /etc/udev/rules.d/50-qmk.rules && udevadm control --reload-rules
    - creates: /etc/udev/rules.d/50-qmk.rules

install_oldschool_pc_fonts:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/share/fonts/oldschool-pc
        curl -fsSL https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_linux.zip -o /tmp/fonts.zip
        unzip -o /tmp/fonts.zip -d /tmp/oldschool-fonts
        find /tmp/oldschool-fonts -name '*.otf' -exec cp {} ~/.local/share/fonts/oldschool-pc/ \;
        fc-cache -f ~/.local/share/fonts/oldschool-pc/
        rm -rf /tmp/fonts.zip /tmp/oldschool-fonts
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/fonts/oldschool-pc

# --- Special: RoomEQ Wizard (Java acoustic measurement) ---
install_roomeqwizard:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/roomeqwizard
        curl -fsSL 'https://www.roomeqwizard.com/installers/REW_linux_no_jre_5_33.zip' -o /tmp/rew.zip
        unzip -o /tmp/rew.zip -d ~/.local/opt/roomeqwizard
        rm -f /tmp/rew.zip
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/opt/roomeqwizard

# --- Throne (sing-box GUI proxy frontend, bundled Qt) ---
install_throne:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/throne
        curl -fsSL https://github.com/throneproj/Throne/releases/download/1.0.13/Throne-1.0.13-linux-amd64.zip -o /tmp/throne.zip
        unzip -o /tmp/throne.zip -d ~/.local/opt/throne
        ln -sf ~/.local/opt/throne/Throne ~/.local/bin/throne
        rm -f /tmp/throne.zip
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/opt/throne

# --- Overskride (Bluetooth GTK4 client, Flatpak bundle from GitHub) ---
install_overskride:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/kaii-lb/overskride/releases/download/v0.6.6/overskride.flatpak -o /tmp/overskride.flatpak
        flatpak install --user -y /tmp/overskride.flatpak
        rm -f /tmp/overskride.flatpak
    - runas: neg
    - shell: /bin/bash
    - unless: flatpak info io.github.kaii_lb.Overskride &>/dev/null

# --- Nyxt browser (Electron AppImage) ---
install_nyxt:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/atlas-engineer/nyxt/releases/download/4.0.0/Linux-Nyxt-x86_64.tar.gz -o /tmp/nyxt.tar.gz
        tar -xzf /tmp/nyxt.tar.gz -C /tmp
        mv /tmp/Nyxt-x86_64.AppImage ~/.local/bin/nyxt
        chmod +x ~/.local/bin/nyxt
        rm -f /tmp/nyxt.tar.gz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/nyxt

# --- Open Sound Meter (FFT acoustic analysis, AppImage) ---
{{ curl_bin('opensoundmeter', 'https://github.com/psmokotnin/osm/releases/download/v1.5.2/Open_Sound_Meter-v1.5.2-x86_64.AppImage') }}

# --- matugen (Material You color generation) ---
{{ github_tar('matugen', 'https://github.com/InioX/matugen/releases/download/v3.1.0/matugen-3.1.0-x86_64.tar.gz') }}

install_matugen_themes:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/InioX/matugen-themes.git /tmp/matugen-themes
        mkdir -p ~/.config/matugen/templates
        cp -r /tmp/matugen-themes/*/ ~/.config/matugen/templates/
        rm -rf /tmp/matugen-themes
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.config/matugen/templates

# --- DroidCam (phone as webcam via v4l2loopback) ---
install_v4l2loopback:
  cmd.run:
    - name: rpm-ostree install -y akmod-v4l2loopback
    - unless: rpm -q akmod-v4l2loopback &>/dev/null || rpm-ostree status | grep -q v4l2loopback

install_droidcam:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://files.dev47apps.net/linux/droidcam_2.1.3.zip -o /tmp/droidcam.zip
        unzip -o /tmp/droidcam.zip -d /tmp/droidcam
        mv /tmp/droidcam/droidcam ~/.local/bin/
        mv /tmp/droidcam/droidcam-cli ~/.local/bin/
        chmod +x ~/.local/bin/droidcam ~/.local/bin/droidcam-cli
        rm -rf /tmp/droidcam.zip /tmp/droidcam
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/bin/droidcam

# --- blesh (Bash Line Editor) ---
install_blesh:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz -o /tmp/blesh.tar.xz
        tar -xJf /tmp/blesh.tar.xz -C ~/.local/share/ --strip-components=1
        rm -f /tmp/blesh.tar.xz
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/ble.sh

# --- hishtory (synced shell history search) ---
{{ github_release('hishtory', 'ddworken/hishtory', 'hishtory-linux-amd64') }}

# --- iwmenu (interactive Wi-Fi menu for iwd/Wayland) ---
{{ cargo_pkg('iwmenu', git='https://github.com/e-tho/iwmenu') }}

# --- rofi-pass (password-store rofi frontend) ---
{{ curl_bin('rofi-pass', 'https://raw.githubusercontent.com/carnager/rofi-pass/master/rofi-pass') }}

# --- Theme packages not in Fedora repos ---
install_kora_icons:
  cmd.run:
    - name: |
        set -eo pipefail
        TAG=$(curl -fsSL https://api.github.com/repos/bikass/kora/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/bikass/kora/archive/refs/tags/${TAG}.tar.gz" -o /tmp/kora.tar.gz
        tar -xzf /tmp/kora.tar.gz -C /tmp
        mkdir -p ~/.local/share/icons
        cp -r /tmp/kora-*/kora ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-light-panel ~/.local/share/icons/
        cp -r /tmp/kora-*/kora-pgrey ~/.local/share/icons/
        gtk-update-icon-cache ~/.local/share/icons/kora 2>/dev/null || true
        rm -rf /tmp/kora.tar.gz /tmp/kora-*
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/icons/kora

install_flight_gtk_theme:
  cmd.run:
    - name: |
        set -eo pipefail
        git clone --depth=1 https://github.com/neg-serg/Flight-Plasma-Themes.git /tmp/flight-gtk
        mkdir -p ~/.local/share/themes
        cp -r /tmp/flight-gtk/Flight-Dark-GTK ~/.local/share/themes/
        cp -r /tmp/flight-gtk/Flight-light-GTK ~/.local/share/themes/
        rm -rf /tmp/flight-gtk
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.local/share/themes/Flight-Dark-GTK

# --- MPV scripts (installed per-user, not in Fedora repos) ---
install_mpv_scripts:
  cmd.run:
    - name: |
        set -eo pipefail
        SCRIPTS_DIR=~/.config/mpv/scripts
        mkdir -p "$SCRIPTS_DIR"
        # uosc (modern UI)
        TAG=$(curl -fsSL https://api.github.com/repos/tomasklaen/uosc/releases/latest | jq -r .tag_name)
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
        TAG=$(curl -fsSL https://api.github.com/repos/hoyon/mpv-mpris/releases/latest | jq -r .tag_name)
        curl -fsSL "https://github.com/hoyon/mpv-mpris/releases/download/${TAG}/mpris.so" -o "$SCRIPTS_DIR/mpris.so"
        # cutter
        curl -fsSL https://raw.githubusercontent.com/rushmj/mpv-video-cutter/master/cutter.lua -o "$SCRIPTS_DIR/cutter.lua"
    - runas: neg
    - shell: /bin/bash
    - creates: /var/home/neg/.config/mpv/scripts/thumbfast.lua
