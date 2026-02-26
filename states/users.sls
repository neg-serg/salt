# User accounts, groups, and sudo configuration
{% from '_imports.jinja' import host, user, home, sudo_timeout_minutes %}
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
        Defaults timestamp_timeout={{ sudo_timeout_minutes }}
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

sudo_nopasswd:
  file.managed:
    - name: /etc/sudoers.d/99-{{ user }}-nopasswd
    - contents: |
        # Package management
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/paru

        # Systemd control
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/journalctl
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/localectl, /usr/bin/timedatectl, /usr/bin/hostnamectl
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/loginctl, /usr/bin/networkctl, /usr/bin/machinectl, /usr/bin/bootctl

        # Storage and filesystems
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/mount, /usr/bin/umount, /usr/bin/btrfs, /usr/bin/snapper

        # Network and VPN
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/ip, /usr/bin/resolvectl, /usr/bin/firewall-cmd
        {{ user }} ALL=(ALL) NOPASSWD: /usr/local/bin/awg, /usr/local/bin/amneziawg-go
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/wg, /usr/bin/wg-quick

        # Kernel and hardware
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/modprobe, /usr/bin/sysctl, /usr/bin/udevadm, /usr/bin/rfkill

        # File operations
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/chmod, /usr/bin/chown, /usr/bin/etckeeper

        # Containers
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/podman

        # Monitoring and diagnostics
        {{ user }} ALL=(ALL) NOPASSWD: /usr/bin/iotop, /usr/bin/lsof, /usr/bin/kmon

        # Salt
        {{ user }} ALL=(ALL) NOPASSWD: {{ home }}/src/salt/.venv/bin/python3, {{ home }}/src/salt/scripts/salt-daemon.py
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f
