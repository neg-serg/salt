{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_service.jinja' import service_stopped %}
# greetd display manager: replace sddm with quickshell greeter

{{ pacman_install('greetd', 'greetd greetd-regreet') }}

{{ service_stopped('disable_sddm', 'sddm') }}

greetd_config_dir:
  file.directory:
    - name: /etc/greetd
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

greetd_config:
  file.managed:
    - name: /etc/greetd/config.toml
    - contents: |
        [terminal]
        vt = 1

        [default_session]
        command = "Hyprland -c /etc/greetd/hyprland-greeter.conf"
        user = "{{ user }}"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_hyprland_config:
  file.managed:
    - name: /etc/greetd/hyprland-greeter.conf
    - source: salt://configs/greetd-hyprland.conf.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_session_wrapper:
  file.managed:
    - name: /etc/greetd/session-wrapper
    - source: salt://scripts/greetd-session-wrapper.sh
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: greetd_config_dir

greetd_wallpaper:
  cmd.run:
    - name: |
        wallpaper=$(tr '\0' '\n' < {{ home }}/.cache/swww/DP-2 2>/dev/null | grep '^/')
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
          cp -f "$wallpaper" {{ home }}/.cache/greeter-wallpaper
        fi
    - runas: {{ user }}
    - unless: test -f {{ home }}/.cache/greeter-wallpaper
    - require:
      - file: greetd_config_dir

greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_config
