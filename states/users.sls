# User accounts, groups, sudo, and user lingering
{% from '_imports.jinja' import host, user, home, sudo_timeout_minutes %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import user_linger %}
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
    - unless: id -nG {{ user }} | grep -qw plugdev
    - require:
      - group: plugdev_group

sudo_timeout:
  file.managed:
    - name: /etc/sudoers.d/timeout
    - contents: |
        Defaults timestamp_timeout={{ sudo_timeout_minutes }}
        Defaults !tty_tickets
        Defaults passprompt="{{ '\uf023' }} "
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

sudo_nopasswd:
  file.managed:
    - name: /etc/sudoers.d/99-{{ user }}-nopasswd
    - source: salt://configs/sudoers-nopasswd.j2
    - template: jinja
    - context:
        user: {{ user }}
        home: {{ home }}
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

# SSH agent authentication for sudo (Yubikey-backed)
# Toggle: host.features.sudo_ssh_agent (hosts.yaml)
{% if host.features.sudo_ssh_agent %}
{{ paru_install('pam_ssh_agent_auth', 'pam_ssh_agent_auth') }}

sudo_pam_config:
  file.managed:
    - name: /etc/pam.d/sudo
    - source: salt://configs/pam-sudo.j2
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: install_pam_ssh_agent_auth

sudo_ssh_agent_env_keep:
  file.managed:
    - name: /etc/sudoers.d/ssh-agent-auth
    - source: salt://configs/sudoers-ssh-agent-auth.j2
    - user: root
    - group: root
    - mode: '0440'
    - check_cmd: /usr/sbin/visudo -c -f

sudo_ssh_agent_authorized_keys:
  file.managed:
    - name: /etc/ssh/sudo_authorized_keys
    - source: salt://configs/sudo-authorized-keys.j2
    - user: root
    - group: root
    - mode: '0644'
{% else %}
# Restore default PAM sudo config (no ssh-agent auth)
sudo_pam_config:
  file.managed:
    - name: /etc/pam.d/sudo
    - contents: |
        #%PAM-1.0
        auth      include     system-auth
        account   include     system-auth
        session   include     system-auth
    - user: root
    - group: root
    - mode: '0644'

sudo_ssh_agent_env_keep:
  file.absent:
    - name: /etc/sudoers.d/ssh-agent-auth
{% endif %}

# ── Lingering (user services survive logout) ──────────────────────────
{{ user_linger('user_lingering') }}
