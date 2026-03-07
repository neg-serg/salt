{% from '_macros_pkg.jinja' import pacman_install %}
# Btrfs snapshot management via snapper + snap-pac + limine-snapper-sync
# Bootstrap creates initial config; this state keeps it converged.

{{ pacman_install('snapper', 'snapper snap-pac') }}

snapper_config_root:
  file.managed:
    - name: /etc/snapper/configs/root
    - source: salt://configs/snapper-root.conf
    - mode: '0640'

snapper_registered:
  file.managed:
    - name: /etc/conf.d/snapper
    - contents: 'SNAPPER_CONFIGS="root"'
    - makedirs: True
    - mode: '0644'

snapper_timers:
  service.enabled:
    - names:
      - snapper-timeline.timer
      - snapper-cleanup.timer
    - require:
      - cmd: install_snapper
