{% from '_imports.jinja' import user, home %}

# Keep only hiddify-next managed outside this repo and remove the legacy
# official AppImage layer that used to shadow its desktop handlers. Keep the
# local wrapper scripts because they patch unsupported loopback tproxy entries
# out of imported configs before launching Hiddify Next.

{% set hiddify_gui = '/usr/lib/hiddify/hiddify' %}
{% set hiddify_cli = '/usr/lib/hiddify/HiddifyCli' %}
{% set hiddify_caps = 'cap_net_admin,cap_net_bind_service,cap_net_raw=ep' %}

hiddify_legacy_cleanup:
  file.absent:
    - names:
      - {{ home }}/.local/bin/Hiddify.AppImage
      - {{ home }}/.local/share/applications/hiddify-official.desktop
      - {{ home }}/.local/share/applications/hiddify-official-root.desktop
      - {{ home }}/.cache/hiddify

hiddify_next_default_handlers:
  cmd.run:
    - name: |
        xdg-mime default hiddify.desktop x-scheme-handler/hiddify
        xdg-mime default hiddify.desktop x-scheme-handler/sing-box
        xdg-mime default hiddify.desktop x-scheme-handler/v2ray
        xdg-mime default hiddify.desktop x-scheme-handler/v2rayn
        xdg-mime default hiddify.desktop x-scheme-handler/v2rayng
        xdg-mime default hiddify.desktop x-scheme-handler/clash
        xdg-mime default hiddify.desktop x-scheme-handler/clashmeta
    - runas: {{ user }}
    - shell: /bin/bash
    - onlyif: test -f /usr/share/applications/hiddify.desktop -o -f {{ home }}/.local/share/applications/hiddify.desktop
    - unless: >-
        grep -q 'x-scheme-handler/hiddify=hiddify.desktop' {{ home }}/.config/mimeapps.list &&
        grep -q 'x-scheme-handler/clashmeta=hiddify.desktop' {{ home }}/.config/mimeapps.list
    - require:
      - file: hiddify_legacy_cleanup

hiddify_gui_capabilities:
  cmd.run:
    - name: setcap {{ hiddify_caps }} {{ hiddify_gui }}
    - runas: root
    - onlyif: test -x {{ hiddify_gui }}
    - unless: getcap {{ hiddify_gui }} 2>/dev/null | grep -q 'cap_net_admin.*cap_net_bind_service.*cap_net_raw'

hiddify_core_cli_capabilities:
  cmd.run:
    - name: setcap {{ hiddify_caps }} {{ hiddify_cli }}
    - runas: root
    - onlyif: test -x {{ hiddify_cli }}
    - unless: getcap {{ hiddify_cli }} 2>/dev/null | grep -q 'cap_net_admin.*cap_net_bind_service.*cap_net_raw'
