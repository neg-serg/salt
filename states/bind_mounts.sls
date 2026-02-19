# Bind mounts for user directories on external storage
# Migrated from NixOS fileSystems (modules/system/filesystems.nix)
#
# Uses mount.fstab_present + cmd.run instead of mount.mounted to avoid
# Salt's device mismatch detection which always triggers remounts on
# bind mounts (kernel reports the underlying block device, not bind source).

{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/bind_mounts.yaml' as mounts %}

{% for name, m in mounts.items() %}
{% set target = home ~ '/' ~ m.target_suffix %}
{{ ensure_dir(name ~ '_mount_point', target) }}

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
