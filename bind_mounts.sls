# Bind mounts for user directories on external storage
# Migrated from NixOS fileSystems (modules/system/filesystems.nix)

{% set user = 'neg' %}
{% set home = '/var/home/' ~ user %}

{% set mounts = [
    {'name': 'music', 'device': '/var/mnt/one/music'},
    {'name': 'vid',   'device': '/var/mnt/one/vid'},
    {'name': 'doc',     'device': '/var/mnt/one/doc'},
    {'name': 'torrent', 'device': '/var/mnt/one/torrent'},
    {'name': 'games',   'device': '/var/mnt/zero/games'},
] %}

# Mail uses a dotpath (~/.local/mail), handled separately
mail_mount_point:
  file.directory:
    - name: {{ home }}/.local/mail
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

mail_mount:
  mount.mounted:
    - name: {{ home }}/.local/mail
    - device: /var/mnt/zero/mail
    - fstype: none
    - opts: rbind,nofail,x-systemd.automount
    - persist: True
    - require:
      - file: mail_mount_point

{% for m in mounts %}
{{ m.name }}_mount_point:
  file.directory:
    - name: {{ home }}/{{ m.name }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{{ m.name }}_mount:
  mount.mounted:
    - name: {{ home }}/{{ m.name }}
    - device: {{ m.device }}
    - fstype: none
    - opts: rbind,nofail,x-systemd.automount
    - persist: True
    - require:
      - file: {{ m.name }}_mount_point
{% endfor %}
