# Bind mounts for user directories on external storage
# Migrated from NixOS fileSystems (modules/system/filesystems.nix)
#
# Uses mount.fstab_present + cmd.run instead of mount.mounted to avoid
# Salt's device mismatch detection which always triggers remounts on
# bind mounts (kernel reports the underlying block device, not bind source).

{% from 'host_config.jinja' import host %}
{% import_yaml 'data/bind_mounts.yaml' as mounts %}
{% set user = host.user %}
{% set home = host.home %}

{% for name, m in mounts.items() %}
{% set target = home ~ '/' ~ m.target_suffix %}
{{ name }}_mount_point:
  file.directory:
    - name: {{ target }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{{ name }}_mount_fstab:
  mount.fstab_present:
    - name: {{ m.device }}
    - fs_file: {{ target }}
    - fs_vfstype: none
    - fs_mntops: rbind,nofail,x-systemd.automount
    - mount: False

{{ name }}_mount:
  cmd.run:
    - name: mount {{ target }}
    - unless: mountpoint -q {{ target }}
    - require:
      - file: {{ name }}_mount_point
      - mount: {{ name }}_mount_fstab
{% endfor %}
