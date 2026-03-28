{% from '_imports.jinja' import home, user %}
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% import_yaml 'data/desktop.yaml' as desktop %}

# --- Hyprland ecosystem packages ---
{{ pacman_install('hyprland_desktop', desktop.hyprland_packages | join(' ')) }}
{{ pacman_install('screenshot_tools', desktop.screenshot_packages | join(' ')) }}
# rsync: file synchronization (used by Salt, backups, dotfile deploys)
{{ pacman_install('rsync', 'rsync') }}
# localsend: LAN file sharing (AirDrop alternative, no internet required)
{{ pacman_install('localsend', 'localsend') }}
# chromium: secondary browser for sites that break on Firefox/Gecko
{{ pacman_install('chromium', 'chromium') }}
# zen-browser: performance-focused Firefox fork with compact UI
{{ pacman_install('zen_browser', 'zen-browser-bin') }}
# xdg-desktop-portal-termfilechooser: conditionally managed in desktop.portal
# wlr-which-key: on-screen keybinding cheatsheet for Hyprland (leader key menu)
{{ paru_install('wlr-which-key', 'wlr-which-key') }}

# --- swayimg: build and install directly from the local checkout ---
swayimg_local_link_absent:
  file.absent:
    - name: {{ home }}/.local/bin/swayimg

swayimg_local_checkout_build:
  cmd.run:
    - name: |
        set -euo pipefail
        src="{{ home }}/src/1st-level/swayimg"
        test -d "$src"
        su - {{ user }} -c 'cd "{{ home }}/src/1st-level/swayimg" && meson setup build-salt --wipe && meson compile -C build-salt'
        meson install -C "$src/build-salt"
        su - {{ user }} -c 'git -C "{{ home }}/src/1st-level/swayimg" describe --tags --long --always' > /usr/local/share/.swayimg-build-version
    - shell: /bin/bash
    - unless: test -f /usr/local/share/.swayimg-build-version && test "$(cat /usr/local/share/.swayimg-build-version)" = "$(su - {{ user }} -c 'git -C {{ home }}/src/1st-level/swayimg describe --tags --long --always')"
    - require:
      - file: swayimg_local_link_absent
