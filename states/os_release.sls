# Manage distro identity used by systemd, systemd-hostnamed, and hostnamectl.

system_os_release:
  file.managed:
    - name: /etc/os-release
    - source: salt://configs/os-release.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
