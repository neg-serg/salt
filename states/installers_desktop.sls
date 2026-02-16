{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import curl_bin, curl_extract_zip %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set user = host.user %}
{% set home = host.home %}
# Desktop application installers: GUI apps, AppImages, AUR packages

# --- RoomEQ Wizard (Java acoustic measurement) ---
install_roomeqwizard:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/roomeqwizard
        curl -fsSL 'https://www.roomeqwizard.com/installers/REW_linux_no_jre_{{ ver.roomeqwizard }}.zip' -o /tmp/rew.zip
        unzip -o /tmp/rew.zip -d ~/.local/opt/roomeqwizard
        rm -f /tmp/rew.zip
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/opt/roomeqwizard

# --- Throne (sing-box GUI proxy frontend, bundled Qt) ---
install_throne:
  cmd.run:
    - name: |
        set -eo pipefail
        mkdir -p ~/.local/opt/throne
        curl -fsSL https://github.com/throneproj/Throne/releases/download/{{ ver.throne }}/Throne-{{ ver.throne }}-linux-amd64.zip -o /tmp/throne.zip
        unzip -o /tmp/throne.zip -d ~/.local/opt/throne
        ln -sf ~/.local/opt/throne/Throne ~/.local/bin/throne
        rm -f /tmp/throne.zip
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/opt/throne

# --- Overskride (Bluetooth GTK4 client, AUR) ---
install_overskride:
  cmd.run:
    - name: sudo -u {{ user }} paru -S --noconfirm --needed overskride-bin
    - unless: pacman -Q overskride-bin &>/dev/null

# --- Nyxt browser (Electron AppImage) ---
install_nyxt:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL https://github.com/atlas-engineer/nyxt/releases/download/{{ ver.nyxt }}/Linux-Nyxt-x86_64.tar.gz -o /tmp/nyxt.tar.gz
        tar -xzf /tmp/nyxt.tar.gz -C /tmp
        mv /tmp/Nyxt-x86_64.AppImage ~/.local/bin/nyxt
        chmod +x ~/.local/bin/nyxt
        rm -f /tmp/nyxt.tar.gz
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/bin/nyxt

# --- Open Sound Meter (FFT acoustic analysis, AppImage) ---
{{ curl_bin('opensoundmeter', 'https://github.com/psmokotnin/osm/releases/download/v' ~ ver.opensoundmeter ~ '/Open_Sound_Meter-v' ~ ver.opensoundmeter ~ '-x86_64.AppImage') }}
# --- DroidCam (phone as webcam via v4l2loopback) ---
# v4l2loopback-dkms installed via pacman outside Salt
{{ curl_extract_zip('droidcam', 'https://files.dev47apps.net/linux/droidcam_' ~ ver.droidcam ~ '.zip', '.', binaries=['droidcam', 'droidcam-cli'], chmod=True) }}
