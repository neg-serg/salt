# Bind mounts for user directories on external storage
# Migrated from NixOS fileSystems (modules/system/filesystems.nix)
#
# Uses mount.fstab_present + cmd.run instead of mount.mounted to avoid
# Salt's device mismatch detection which always triggers remounts on
# bind mounts (kernel reports the underlying block device, not bind source).

{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}

{% set mounts = [
    {'name': 'mail',    'device': '/mnt/zero/mail',    'target': home ~ '/.local/mail'},
    {'name': 'music',   'device': '/mnt/one/music',    'target': home ~ '/music'},
    {'name': 'vid',     'device': '/mnt/one/vid',      'target': home ~ '/vid'},
    {'name': 'doc',     'device': '/mnt/one/doc',      'target': home ~ '/doc'},
    {'name': 'torrent', 'device': '/mnt/one/torrent',  'target': home ~ '/torrent'},
    {'name': 'games',   'device': '/mnt/zero/games',   'target': home ~ '/games'},
] %}

{% for m in mounts %}
{{ m.name }}_mount_point:
  file.directory:
    - name: {{ m.target }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{{ m.name }}_mount_fstab:
  mount.fstab_present:
    - name: {{ m.device }}
    - fs_file: {{ m.target }}
    - fs_vfstype: none
    - fs_mntops: rbind,nofail,x-systemd.automount
    - mount: False

{{ m.name }}_mount:
  cmd.run:
    - name: mount {{ m.target }}
    - unless: mountpoint -q {{ m.target }}
    - require:
      - file: {{ m.name }}_mount_point
      - mount: {{ m.name }}_mount_fstab
{% endfor %}
