{% from '_imports.jinja' import user, home %}

# Keep only hiddify-next managed outside this repo and remove the legacy
# official AppImage layer that used to shadow its desktop handlers.

hiddify_legacy_cleanup:
  file.absent:
    - names:
      - {{ home }}/.local/bin/Hiddify.AppImage
      - {{ home }}/.local/bin/hiddify-launch
      - {{ home }}/.local/bin/hiddify-root
      - {{ home }}/.local/bin/hiddify-fix-loopback
      - {{ home }}/.local/share/applications/hiddify-official.desktop
      - {{ home }}/.local/share/applications/hiddify-official-root.desktop
      - {{ home }}/.cache/hiddify
      - {{ home }}/.local/share/app.hiddify.com

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
    - unless: |
        test "$(xdg-mime query default x-scheme-handler/hiddify)" = "hiddify.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/sing-box)" = "hiddify.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/v2ray)" = "hiddify.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/v2rayn)" = "hiddify.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/v2rayng)" = "hiddify.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/clash)" = "hiddify.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/clashmeta)" = "hiddify.desktop"
    - require:
      - file: hiddify_legacy_cleanup
