# Zsh: system-wide config, ZDOTDIR, user dotfiles, force shell for users
{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set home = host.home %}

zsh_config_dir:
  file.directory:
    - name: /etc/zsh
    - user: root
    - group: root
    - mode: '0755'

/etc/zsh/zshenv:
  file.managed:
    - contents: |
        # System-wide Zsh environment (zsh reads /etc/zsh/ on Arch)
        export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

/etc/zsh/zshrc:
  file.managed:
    - contents: |
        # System-wide zshrc (ZDOTDIR set in /etc/zsh/zshenv)
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

cleanup_old_etc_zshenv:
  file.absent:
    - name: /etc/zshenv

# --- User zsh dotfiles (deployed from chezmoi source) ---
user_zsh_config_dir:
  file.directory:
    - name: {{ home }}/.config/zsh
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

zsh_env:
  file.managed:
    - name: {{ home }}/.config/zsh/.zshenv
    - source: salt://dotfiles/dot_config/zsh/dot_zshenv
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'

zsh_rc:
  file.managed:
    - name: {{ home }}/.config/zsh/.zshrc
    - source: salt://dotfiles/dot_config/zsh/dot_zshrc
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'

force_zsh_neg:
  cmd.run:
    - name: usermod -s /usr/bin/zsh {{ user }}
    - unless: 'test "$(getent passwd {{ user }} | cut -d: -f7)" = "/usr/bin/zsh"'

force_zsh_root:
  cmd.run:
    - name: usermod -s /usr/bin/zsh root
    - unless: 'test "$(getent passwd root | cut -d: -f7)" = "/usr/bin/zsh"'
