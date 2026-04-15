# Windows NTFS partition — automount on first access.
# Uses x-systemd.automount so the partition is NOT mounted at boot.
# The ntfs3 in-kernel driver is used (no extra package needed on Linux 5.15+).
{% import_yaml 'data/windows_mount.yaml' as mounts %}

{% for name, m in mounts.items() %}
{% set _fs = m.get('fs_type', 'ntfs3') %}
{% set _opts = m.get('options', 'rw,nofail,x-systemd.automount,x-systemd.idle-timeout=60') %}

{{ name }}_mount_point:
  file.directory:
    - name: {{ m.mount_point }}
    - mode: '0755'

{{ name }}_mount_fstab:
  mount.fstab_present:
    - name: {{ m.device }}
    - fs_file: {{ m.mount_point }}
    - fs_vfstype: {{ _fs }}
    - fs_mntops: {{ _opts }}
    - mount: False
{% endfor %}
