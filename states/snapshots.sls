# Btrfs snapshot management via snapper + snap-pac + limine-snapper-sync
# Bootstrap creates initial config; this state keeps it converged.

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

snapper_timeline_timer:
  service.enabled:
    - name: snapper-timeline.timer

snapper_cleanup_timer:
  service.enabled:
    - name: snapper-cleanup.timer
