{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_service.jinja' import ensure_dir %}
# greetd display manager: cage kiosk compositor + quickshell greeter

include:
  - systemd_resources

{{ pacman_install('greetd', 'greetd') }}
{{ pacman_install('cage', 'cage') }}
{{ pacman_install('wlr_randr', 'wlr-randr') }}

{{ ensure_dir('greetd_config_dir', '/etc/greetd', mode='0755', user='root') }}

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
    - context:
        greetd_scale: {{ host.greetd_scale }}
        cursor_theme: {{ host.cursor_theme }}
        cursor_size: {{ host.cursor_size }}
        home: {{ home }}
        primary_output: {{ host.primary_output }}
        display: {{ host.display }}
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
        wallpaper=$(tr '\0' '\n' < {{ home }}/.cache/wl/{{ host.primary_output }} 2>/dev/null | rg '^/')
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
          cp -f "$wallpaper" {{ home }}/.cache/greeter-wallpaper
        fi
    - runas: {{ user }}
    - shell: /bin/bash
    - unless: |
        [ -f {{ home }}/.cache/greeter-wallpaper ] &&
        [ ! {{ home }}/.cache/wl/{{ host.primary_output }} -nt {{ home }}/.cache/greeter-wallpaper ]
    - require:
      - file: greetd_config_dir
{% endif %}

greetd_cleanup_stale:
  file.absent:
    - names:
      - /etc/greetd/config.toml.pacnew
      - /etc/greetd/regreet.toml
      - /etc/greetd/hyprland-greeter.conf

greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_main_config
      - cmd: managed_service_accounts_ensure
      - cmd: managed_service_paths_ensure

# Emergency TTY: Ctrl+Alt+F2 always drops to a text login,
# even if the graphical greeter is frozen or broken.
greetd_emergency_tty:
  service.enabled:
    - name: getty@tty2
