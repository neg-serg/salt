# Disk mounts (/mnt/zero, /mnt/one), btrfs compression and nocow
{% from '_imports.jinja' import home %}
{% import_yaml 'data/mounts.yaml' as mounts %}

{% for name, m in mounts.disks.items() %}
{{ name }}_dir:
  file.directory:
    - name: {{ m.path }}
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
    - require:
      - file: {{ name }}_dir
{% endfor %}
