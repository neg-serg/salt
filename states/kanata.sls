{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir, user_service_file, user_service_enable %}
# Kanata: software keyboard remapper (uinput-based)
{% if host.features.kanata %}

# --- Install kanata binary from GitHub release ---
# Binary inside the zip is named kanata_linux_x64, not kanata
install_kanata:
  cmd.run:
    - name: |
        set -eo pipefail
        curl -fsSL "https://github.com/jtroo/kanata/releases/latest/download/linux-binaries-x64.zip" -o /tmp/kanata.zip
        unzip -o /tmp/kanata.zip -d /tmp/kanata_extracted
        mv /tmp/kanata_extracted/kanata_linux_x64 {{ home }}/.local/bin/kanata
        chmod +x {{ home }}/.local/bin/kanata
        rm -rf /tmp/kanata.zip /tmp/kanata_extracted
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ home }}/.local/bin/kanata
    - parallel: True
    - retry:
        attempts: 3
        interval: 10

# --- uinput kernel module (required for virtual keyboard device) ---
kanata_uinput_module:
  file.managed:
    - name: /etc/modules-load.d/uinput.conf
    - contents: uinput
    - mode: '0644'

kanata_load_uinput:
  kmod.present:
    - name: uinput
    - persist: False
    - require:
      - file: kanata_uinput_module

# --- udev rule: allow uinput group to access /dev/uinput ---
kanata_udev_rule:
  file.managed:
    - name: /etc/udev/rules.d/99-uinput.rules
    - contents: 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"'
    - mode: '0644'

kanata_udev_reload:
  cmd.run:
    - name: udevadm control --reload-rules && udevadm trigger
    - onchanges:
      - file: kanata_udev_rule

# --- Groups: uinput + input ---
uinput_group:
  group.present:
    - name: uinput
    - system: True

kanata_user_groups:
  cmd.run:
    - name: usermod -aG input,uinput {{ user }}
    - unless: id -nG {{ user }} | tr ' ' '\n' | rg -qx uinput
    - require:
      - group: uinput_group

# --- Config ---
{{ ensure_dir('kanata_config_dir', home ~ '/.config/kanata') }}

kanata_config:
  file.managed:
    - name: {{ home }}/.config/kanata/config.kbd
    - source: salt://configs/kanata.kbd
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - replace: False
    - require:
      - file: kanata_config_dir

# --- Systemd user service ---
{{ user_service_file('kanata_service', 'kanata.service') }}

{{ user_service_enable('kanata_enabled', ['kanata.service'], daemon_reload=True, requires=['cmd: install_kanata', 'file: kanata_config', 'file: kanata_service', 'cmd: kanata_user_groups', 'kmod: kanata_load_uinput']) }}
{% endif %}
