{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_service.jinja' import service_stopped %}
# greetd display manager: cage kiosk compositor + quickshell greeter

{{ pacman_install('greetd', 'greetd') }}
{{ pacman_install('cage', 'cage') }}

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
        command = "/etc/greetd/greeter-wrapper"
        user = "{{ user }}"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_greeter_wrapper:
  file.managed:
    - name: /etc/greetd/greeter-wrapper
    - source: salt://scripts/greetd-greeter-wrapper.sh.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'
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

{% if host.primary_output %}
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
{% endif %}

greetd_cleanup_pacnew:
  file.absent:
    - name: /etc/greetd/config.toml.pacnew

greetd_cleanup_regreet:
  file.absent:
    - name: /etc/greetd/regreet.toml

greetd_cleanup_hyprland:
  file.absent:
    - name: /etc/greetd/hyprland-greeter.conf

greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_main_config
