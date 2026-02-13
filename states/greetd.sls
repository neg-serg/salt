# greetd display manager: replace sddm with quickshell greeter
{% from '_macros.jinja' import selinux_policy %}

disable_sddm:
  service.dead:
    - name: sddm
    - enable: False

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
        user = "neg"
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
    - contents: |
        #!/bin/sh
        [ -f /etc/profile ] && . /etc/profile
        set -a
        [ -f "$HOME/.config/environment.d/10-user.conf" ] && . "$HOME/.config/environment.d/10-user.conf"
        set +a
        exec /usr/bin/starthyprland
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: greetd_config_dir

greetd_wallpaper:
  cmd.run:
    - name: |
        wallpaper=$(tr '\0' '\n' < /var/home/neg/.cache/swww/DP-2 2>/dev/null | grep '^/')
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
          cp -f "$wallpaper" /var/home/neg/.cache/greeter-wallpaper
        fi
    - runas: neg
    - unless: test -f /var/home/neg/.cache/greeter-wallpaper
    - require:
      - file: greetd_config_dir

# SELinux: allow greeter (xdm_t) to mmap fontconfig cache and read wallpaper from user cache
{% call selinux_policy('greetd_selinux_cache', 'greetd-cache') %}
module greetd-cache 1.0;
require {
    type xdm_t;
    type cache_home_t;
    type user_fonts_cache_t;
    class file { read open getattr map };
}
allow xdm_t user_fonts_cache_t:file map;
allow xdm_t cache_home_t:file { read open getattr map };
{% endcall %}

greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_config
      - cmd: install_custom_rpms
