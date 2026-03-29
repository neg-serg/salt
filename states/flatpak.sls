{% from '_imports.jinja' import user, retry_attempts, retry_interval %}
{% from '_macros_pkg.jinja' import pacman_install, flatpak_install %}
# Flatpak: install runtime + flathub remote + user-level apps
{% import_yaml 'data/flatpak.yaml' as flatpak %}

{{ pacman_install('flatpak', 'flatpak') }}

flatpak_flathub_remote:
  cmd.run:
    - name: sudo -u {{ user }} flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    - unless: sudo -u {{ user }} flatpak remotes --user --columns=name | grep -qx 'flathub'
    - require:
      - cmd: install_flatpak
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

{% for app_id in flatpak.apps %}
{{ flatpak_install(app_id) }}
{% endfor %}
