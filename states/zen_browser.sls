{% from '_imports.jinja' import host, user, home %}
# Zen Browser: user.js + userChrome.css (bottom navbar)
{% if host.zen_profile %}
{% set zen_profile = home ~ '/.config/zen/' ~ host.zen_profile %}
{% for state_id, relpath, source in [
  ('zen_user_js', 'user.js', 'salt://dotfiles/dot_config/zen-browser/user.js'),
  ('zen_userchrome', 'chrome/userChrome.css', 'salt://dotfiles/dot_config/zen-browser/userChrome.css'),
] %}
{{ state_id }}:
  file.managed:
    - name: {{ zen_profile }}/{{ relpath }}
    - source: {{ source }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
{% endfor %}
{% endif %}
