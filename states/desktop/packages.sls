{% from '_imports.jinja' import home, user %}
{% from '_macros_pkg.jinja' import paru_install %}
{% import_yaml 'data/desktop.yaml' as desktop %}

# --- Hyprland ecosystem packages ---
{{ paru_install('hyprland_desktop', desktop.hyprland_packages | join(' ')) }}
{{ paru_install('screenshot_tools', desktop.screenshot_packages | join(' ')) }}
{{ paru_install('rsync', 'rsync') }} # rsync: file synchronization (used by Salt, backups, dotfile deploys)
{{ paru_install('localsend', 'localsend') }} # localsend: LAN file sharing (AirDrop alternative, AUR)
{{ paru_install('chromium', 'chromium') }} # chromium: secondary browser for sites that break on Firefox/Gecko
{{ paru_install('google_chrome', 'google-chrome') }} # google-chrome: Google Chrome stable (AUR), for testing and Google-specific integrations
{{ paru_install('zen_browser', 'zen-browser-bin') }} # zen-browser: performance-focused Firefox fork with compact UI (AUR)
# xdg-desktop-portal-termfilechooser: conditionally managed in desktop.portal
# wlr-which-key: on-screen keybinding cheatsheet for Hyprland (leader key menu)
{{ paru_install('wlr-which-key', 'wlr-which-key') }}

# --- swayimg: install from the master branch of the local checkout ---
swayimg_local_link_absent:
  file.absent:
    - name: {{ home }}/.local/bin/swayimg

swayimg_local_checkout_build:
  cmd.run:
    - name: |
        set -euo pipefail
        src="{{ home }}/src/1st-level/swayimg"
        test -d "$src"
        su - {{ user }} -c 'cd "{{ home }}/src/1st-level/swayimg" && git checkout master && git pull --ff-only'
        su - {{ user }} -c 'cd "{{ home }}/src/1st-level/swayimg" && meson setup build-salt --wipe && meson compile -C build-salt'
        meson install -C "$src/build-salt"
        su - {{ user }} -c 'git -C "{{ home }}/src/1st-level/swayimg" describe --tags --long --always' > /usr/local/share/.swayimg-build-version
    - shell: /bin/bash
    - unless: test -f /usr/local/bin/swayimg && test -f /usr/local/share/.swayimg-build-version && test "$(cat /usr/local/share/.swayimg-build-version)" = "$(su - {{ user }} -c 'git -C {{ home }}/src/1st-level/swayimg describe --tags --long --always')"
    - require:
      - file: swayimg_local_link_absent
