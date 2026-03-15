{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import udev_rule, ensure_dir, user_service_with_unit %}
# Kanata: software keyboard remapper (uinput-based)
# --- Install kanata from AUR ---
{{ paru_install('kanata', 'kanata-bin') }}

# One-time cleanup: remove old manually-installed binary
kanata_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/kanata
    - onlyif: test -f {{ home }}/.local/bin/kanata

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
