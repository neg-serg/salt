# mkinitcpio: manage initramfs configuration (compression, hooks)
# Optimizes boot speed by using fast zstd compression instead of archival-level.

mkinitcpio_config:
  file.managed:
    - name: /etc/mkinitcpio.conf
    - source: salt://configs/mkinitcpio.conf.j2
    - template: jinja
    - mode: '0644'

mkinitcpio_rebuild:
  cmd.run:
    - name: mkinitcpio -P
    - onchanges:
      - file: mkinitcpio_config
