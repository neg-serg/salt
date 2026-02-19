# Zsh: system-wide config, ZDOTDIR, user dotfiles, force shell for users
{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir %}

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

# --- User zsh dotfiles (deployed from chezmoi source) ---
{{ ensure_dir('user_zsh_config_dir', home ~ '/.config/zsh') }}

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

