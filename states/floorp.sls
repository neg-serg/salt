{% from '_imports.jinja' import host, user, home %}
{% from '_macros_desktop.jinja' import browser_extensions %}
{% from '_macros_install.jinja' import git_clone_deploy %}
# Floorp browser: user.js + userChrome.css + userContent.css + extensions
{% if host.features.floorp and host.floorp_profile %}
{% import_yaml 'data/floorp.yaml' as floorp %}
{% set floorp_profile = home ~ '/.floorp/' ~ host.floorp_profile %}
{% for state_id, relpath, source in [
  ('floorp_user_js', 'user.js', 'salt://dotfiles/dot_config/floorp/user.js'),
  ('floorp_userchrome', 'chrome/userChrome.css', 'salt://dotfiles/dot_config/floorp/userChrome.css'),
  ('floorp_usercontent', 'chrome/userContent.css', 'salt://dotfiles/dot_config/floorp/userContent.css'),
  ('floorp_custom_userchrome', 'chrome/custom/userChrome.css', 'salt://dotfiles/dot_config/floorp/custom/userChrome.css'),
  ('floorp_custom_usercontent', 'chrome/custom/userContent.css', 'salt://dotfiles/dot_config/floorp/custom/userContent.css'),
] %}
{{ state_id }}:
  file.managed:
    - name: {{ floorp_profile }}/{{ relpath }}
    - source: {{ source }}
{% if state_id == 'floorp_user_js' %}
    - template: jinja
    - context:
        home: {{ home }}
{% endif %}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
{% endfor %}

{{ git_clone_deploy('neptune_theme', 'https://github.com/yiiyahui/Neptune-Firefox.git', floorp_profile ~ '/chrome', items=['chrome/neptune'], creates=floorp_profile ~ '/chrome/neptune/theme/main.css') }}

{{ browser_extensions('floorp', floorp_profile, floorp.extensions, 'floorp_user_js', unwanted=floorp.unwanted) }}
{% endif %}
