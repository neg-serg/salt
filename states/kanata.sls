{% from '_imports.jinja' import host, user, home %}
{% from '_macros_install.jinja' import curl_extract_zip %}
{% from '_macros_service.jinja' import udev_rule, ensure_dir, user_service_with_unit %}
{% import_yaml 'data/versions.yaml' as ver %}
# Kanata: software keyboard remapper (uinput-based)
{% if host.features.kanata %}
# --- Install kanata binary from GitHub release ---
# Binary inside the zip is named kanata_linux_x64, not kanata
{{ curl_extract_zip('kanata', 'https://github.com/jtroo/kanata/releases/download/v' ~ ver.kanata ~ '/linux-binaries-x64.zip', 'kanata_linux_x64', bin='kanata', chmod=True, version=ver.kanata) }}

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
{{ udev_rule('kanata_udev_rule', '/etc/udev/rules.d/99-uinput.rules', contents='KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"') }}

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
{{ user_service_with_unit('kanata', 'kanata.service', requires=['cmd: install_kanata', 'file: kanata_config', 'cmd: kanata_user_groups', 'kmod: kanata_load_uinput']) }}
{% endif %}
