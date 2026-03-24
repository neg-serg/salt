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
# kitty desktop-ui provides the FileChooser portal backend
# wlr-which-key: on-screen keybinding cheatsheet for Hyprland (leader key menu)
{{ paru_install('wlr-which-key', 'wlr-which-key') }}

# --- swayimg: use local build from ~/src/swayimg instead of pacman binary ---
swayimg_local_build:
  file.symlink:
    - name: {{ home }}/.local/bin/swayimg
    - target: {{ home }}/src/swayimg/build/swayimg
    - force: True
    - user: {{ user }}
    - group: {{ user }}
