# User accounts, groups, and sudo configuration
{% from '_imports.jinja' import host, user, home %}
{% set uid = host.uid %}

user_root:
  user.present:
    - name: root
    - shell: /usr/bin/zsh

user_neg:
  user.present:
    - name: {{ user }}
    - shell: /usr/bin/zsh
    - uid: {{ uid }}
    - gid: {{ uid }}
    - failhard: True

plugdev_group:
  group.present:
    - name: plugdev
    - system: True

# user.present groups broken on Python 3.14 (crypt module removed)
neg_groups:
  cmd.run:
    - name: usermod -aG wheel,libvirt,plugdev {{ user }}
    - unless: id -nG {{ user }} | tr ' ' '\n' | rg -qx plugdev
    - require:
      - group: plugdev_group

sudo_timeout:
  file.managed:
    - name: /etc/sudoers.d/timeout
    - contents: |
        Defaults timestamp_timeout=30
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

sudo_nopasswd:
  file.managed:
    - name: /etc/sudoers.d/99-{{ user }}-nopasswd
    - contents: |
        # Salt/paru/system management — passwordless
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/paru
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/journalctl
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount, /usr/bin/btrfs
        {{ user }} ALL=(ALL) NOPASSWD: {{ home }}/src/salt/.venv/bin/python3, {{ home }}/src/salt/scripts/salt-daemon.py
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/ip, /usr/bin/resolvectl, /usr/bin/udevadm
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/podman
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f
