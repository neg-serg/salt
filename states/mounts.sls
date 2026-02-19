# Disk mounts (/mnt/zero, /mnt/one) and btrfs compression
{% import_yaml 'data/mounts.yaml' as mounts %}

{% for name, m in mounts.disks.items() %}
{{ m.path }}:
  file.directory:
    - makedirs: True

mount_{{ name }}:
  mount.mounted:
    - name: {{ m.path }}
    - device: {{ m.device }}
    - fstype: {{ m.fstype }}
    - mkmnt: True
    - opts: noatime
    - persist: True
    - failhard: True
{% endfor %}

# btrfs compression: set as filesystem property (complements fstab compress= option).
{% for path in mounts.btrfs_compress %}
btrfs_compress_{{ path.replace('/', '') }}:
  cmd.run:
    - name: btrfs property set {{ path }} compression zstd:-1
    - unless: btrfs property get {{ path }} compression 2>/dev/null | rg -q 'zstd:-1'
{% endfor %}
