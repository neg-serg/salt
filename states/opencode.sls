{% from '_imports.jinja' import user, home %}
# OpenCode AI coding agent: TUI config + neg custom theme

opencode_config:
  file.recurse:
    - name: {{ home }}/.config/opencode
    - source: salt://dotfiles/dot_config/opencode
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
