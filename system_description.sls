# Salt state для Fedora Silverblue
# Учитывает иммутабельность файловой системы

system_timezone:
  timezone.system:
    - name: Europe/Moscow

system_hostname:
  cmd.run:
    - name: hostnamectl set-hostname fedora
    - unless: test "$(hostname)" = "fedora"

user_neg:
  user.present:
    - name: neg
    - shell: /bin/bash
    - uid: 1000
    - gid: 1000
    - groups:
      - neg

# Для Silverblue используем rpm-ostree через cmd.run, 
# так как нативного модуля в этой версии Salt нет.
{% for pkg in ['salt', 'ripgrep', 'tig', 'zsh', 'tree-sitter-cli', 'xsel', 'yt-dlp'] %}
ensure_pkg_{{ pkg }}:
  cmd.run:
    - name: rpm-ostree install {{ pkg }}
    - unless: rpm -q {{ pkg }}
{% endfor %}

running_services:
  service.running:
    - names:
      - NetworkManager
      - firewalld
      - chronyd
      - dbus-broker
      - bluetooth
    - enable: True
