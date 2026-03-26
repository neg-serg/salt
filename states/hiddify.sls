{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval, ver_dir %}
{% from '_macros_common.jinja' import ver_stamp %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/versions.yaml' as ver %}
{% set hiddify_ver = ver.get('hiddify', '') %}
{% set hiddify_url = 'https://github.com/hiddify/hiddify-app/releases/download/v' ~ hiddify_ver ~ '/Hiddify-Linux-x64.AppImage' %}
{% set hiddify_app = home ~ '/.local/bin/Hiddify.AppImage' %}
{% set hiddify_cache = home ~ '/.cache/hiddify/Hiddify-' ~ hiddify_ver ~ '.AppImage' %}

# Official Hiddify AppImage install + launchers, without AUR.
# The launch wrappers scrub broken ::1 loopback bindings before startup.

{{ ensure_dir('hiddify_user_bin_dir', home ~ '/.local/bin') }}
{{ ensure_dir('hiddify_apps_dir', home ~ '/.local/share/applications') }}
{{ ensure_dir('hiddify_cache_dir', home ~ '/.cache/hiddify') }}

hiddify_appimage:
  cmd.run:
    - name: |
        set -eo pipefail
        cache='{{ hiddify_cache }}'
        target='{{ hiddify_app }}'
        if [ ! -f "$cache" ]; then
          curl -fsSL '{{ hiddify_url }}' -o "$cache.tmp"
          mv -f "$cache.tmp" "$cache"
        fi
        cp "$cache" "$target.tmp"
        chmod 0755 "$target.tmp"
        mv -f "$target.tmp" "$target"
        {{ ver_stamp(ver_dir, 'hiddify', hiddify_ver, target=hiddify_app) }}
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ ver_dir }}/hiddify@{{ hiddify_ver }}
    - require:
      - file: hiddify_user_bin_dir
      - file: hiddify_cache_dir
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

hiddify_launch_wrapper:
  file.managed:
    - name: {{ home }}/.local/bin/hiddify-launch
    - source: salt://dotfiles/dot_local/bin/executable_hiddify-launch
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hiddify_user_bin_dir

hiddify_fix_loopback_wrapper:
  file.managed:
    - name: {{ home }}/.local/bin/hiddify-fix-loopback
    - source: salt://dotfiles/dot_local/bin/executable_hiddify-fix-loopback
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hiddify_user_bin_dir

hiddify_root_wrapper:
  file.managed:
    - name: {{ home }}/.local/bin/hiddify-root
    - source: salt://dotfiles/dot_local/bin/executable_hiddify-root
    - mode: '0755'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hiddify_user_bin_dir

hiddify_desktop_entry:
  file.managed:
    - name: {{ home }}/.local/share/applications/hiddify-official.desktop
    - source: salt://dotfiles/dot_local/share/applications/hiddify-official.desktop
    - mode: '0644'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hiddify_apps_dir

hiddify_root_desktop_entry:
  file.managed:
    - name: {{ home }}/.local/share/applications/hiddify-official-root.desktop
    - source: salt://dotfiles/dot_local/share/applications/hiddify-official-root.desktop
    - mode: '0644'
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hiddify_apps_dir

hiddify_runtime_loopback_fix:
  cmd.run:
    - name: {{ home }}/.local/bin/hiddify-fix-loopback
    - runas: {{ user }}
    - onlyif: test -f {{ home }}/.local/share/app.hiddify.com/data/current-config.json
    - require:
      - file: hiddify_fix_loopback_wrapper

hiddify_default_handlers:
  cmd.run:
    - name: |
        xdg-mime default hiddify-official.desktop x-scheme-handler/hiddify
        xdg-mime default hiddify-official.desktop x-scheme-handler/sing-box
        xdg-mime default hiddify-official.desktop x-scheme-handler/v2ray
        xdg-mime default hiddify-official.desktop x-scheme-handler/v2rayn
        xdg-mime default hiddify-official.desktop x-scheme-handler/v2rayng
        xdg-mime default hiddify-official.desktop x-scheme-handler/clash
        xdg-mime default hiddify-official.desktop x-scheme-handler/clashmeta
    - runas: {{ user }}
    - shell: /bin/bash
    - unless: |
        test "$(xdg-mime query default x-scheme-handler/hiddify)" = "hiddify-official.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/sing-box)" = "hiddify-official.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/v2ray)" = "hiddify-official.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/v2rayn)" = "hiddify-official.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/v2rayng)" = "hiddify-official.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/clash)" = "hiddify-official.desktop" &&
        test "$(xdg-mime query default x-scheme-handler/clashmeta)" = "hiddify-official.desktop"
    - require:
      - file: hiddify_desktop_entry

hiddify_legacy_cleanup:
  file.absent:
    - names:
      - /opt/hiddify-next
      - /usr/share/applications/hiddify.desktop
