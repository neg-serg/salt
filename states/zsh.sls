# Zsh: system-wide config, ZDOTDIR, user dotfiles, force shell for users
{% from '_imports.jinja' import user, home %}
{% from '_macros_service.jinja' import ensure_dir %}

{%- macro user_config_file(state_id, path, source, mode='0644') -%}
{{ state_id }}:
  file.managed:
    - name: {{ path }}
    - source: {{ source }}
    - user: {{ user }}
    - group: {{ user }}
    - mode: '{{ mode }}'
{%- endmacro -%}
{{ ensure_dir('zsh_config_dir', '/etc/zsh', mode='0755', user='root') }}

zsh_system_env:
  file.managed:
    - name: /etc/zsh/zshenv
    - contents: |
        # System-wide Zsh environment (zsh reads /etc/zsh/ on Arch)
        export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

zsh_system_rc:
  file.managed:
    - name: /etc/zsh/zshrc
    - contents: |
        # System-wide zshrc (ZDOTDIR set in /etc/zsh/zshenv)
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: zsh_config_dir

# --- User zsh dotfiles (deployed from chezmoi source) ---
{{ ensure_dir('user_zsh_config_dir', home ~ '/.config/zsh') }}
{{ user_config_file('zsh_env', home ~ '/.config/zsh/.zshenv', 'salt://dotfiles/dot_config/zsh/dot_zshenv') }}
{{ user_config_file('zsh_rc', home ~ '/.config/zsh/.zshrc', 'salt://dotfiles/dot_config/zsh/dot_zshrc') }}
