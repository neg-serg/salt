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
{% endfor %}

# btrfs compression: set as filesystem property (complements fstab compress= option).
{% for path in mounts.btrfs_compress %}
btrfs_compress_{{ path.replace('/', '') }}:
  cmd.run:
    - name: btrfs property set "{{ path }}" compression zstd:-1
    - unless: btrfs property get "{{ path }}" compression 2>/dev/null | rg -q 'zstd:-1'
{% endfor %}

# btrfs nocow: disable copy-on-write for high-churn ephemeral data.
# chattr +C only affects new files; existing files retain CoW until recreated.
{% set user_nocow = [
  home ~ '/.cache',
  home ~ '/.local/share/ollama',
] %}
{% for path in mounts.btrfs_nocow + user_nocow %}
{% set id = path.replace('.', '').lstrip('/').replace('/', '_') %}
nocow_{{ id }}:
  cmd.run:
    - name: chattr +C "{{ path }}"
    - unless: lsattr -d "{{ path }}" 2>/dev/null | awk '{print $1}' | rg -q C
    - onlyif: test -d "{{ path }}"
{% endfor %}
