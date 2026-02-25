{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_service.jinja' import service_stopped %}
# greetd display manager: replace sddm with quickshell greeter

{{ pacman_install('greetd', 'greetd') }}

{{ service_stopped('sddm_stopped', 'sddm') }}

greetd_config_dir:
  file.directory:
    - name: /etc/greetd
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

greetd_main_config:
  file.managed:
    - name: /etc/greetd/config.toml
    - contents: |
        [terminal]
        vt = {{ host.greetd_vt }}

        [default_session]
        command = "start-hyprland -- -c /etc/greetd/hyprland-greeter.conf"
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
        wallpaper=$(tr '\0' '\n' < {{ home }}/.cache/swww/{{ host.primary_output }} 2>/dev/null | rg '^/')
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
          cp -f "$wallpaper" {{ home }}/.cache/greeter-wallpaper
        fi
    - runas: {{ user }}
    - unless: |
        [ -f {{ home }}/.cache/greeter-wallpaper ] &&
        [ ! {{ home }}/.cache/swww/{{ host.primary_output }} -nt {{ home }}/.cache/greeter-wallpaper ]
    - require:
      - file: greetd_config_dir

greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_main_config
