{% from '_imports.jinja' import host, user, home %}
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% from '_macros_service.jinja' import ensure_dir %}
# greetd display manager: sysc-greet TUI greeter on Hyprland compositor

include:
  - systemd_resources

{{ pacman_install('greetd', 'greetd') }}
{{ paru_install('sysc_greet', 'sysc-greet-hyprland') }}

{{ ensure_dir('greetd_config_dir', '/etc/greetd', mode='0755', user='root') }}

greetd_main_config:
  file.managed:
    - name: /etc/greetd/config.toml
    - contents: |
        [terminal]
        vt = {{ host.greetd_vt }}

        [default_session]
        command = "start-hyprland -- --config /etc/greetd/hyprland-greeter-config.conf"
        user = "greeter"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: greetd_config_dir

greetd_cleanup_stale:
  file.absent:
    - names:
      - /etc/greetd/config.toml.pacnew
      - /etc/greetd/config.toml.bak
      - /etc/greetd/regreet.toml
      - /etc/greetd/greeter-wrapper
      - /etc/greetd/session-wrapper

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
