# Btrfs snapshot management via snapper + snap-pac + limine-snapper-sync
# Bootstrap creates initial config; this state keeps it converged.

snapper_config_root:
  file.managed:
    - name: /etc/snapper/configs/root
    - mode: '0640'
    - contents: |
        SUBVOLUME="/"
        FSTYPE="btrfs"
        QGROUP=""

        # timeline snapshot limits
        TIMELINE_MIN_AGE="1800"
        TIMELINE_LIMIT_HOURLY="5"
        TIMELINE_LIMIT_DAILY="7"
        TIMELINE_LIMIT_WEEKLY="4"
        TIMELINE_LIMIT_MONTHLY="3"
        TIMELINE_LIMIT_YEARLY="0"

        # cleanup
        NUMBER_MIN_AGE="1800"
        NUMBER_LIMIT="20"
        NUMBER_LIMIT_IMPORTANT="10"

        TIMELINE_CREATE="yes"
        TIMELINE_CLEANUP="yes"

        # snap-pac: pre/post snapshots on pacman transactions
        NUMBER_CLEANUP="yes"

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
