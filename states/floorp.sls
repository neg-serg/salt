{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_install.jinja' import firefox_extension, git_clone_deploy %}
# Floorp browser: user.js + userChrome.css + userContent.css + extensions
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

{{ ensure_dir('floorp_extensions_dir', floorp_profile ~ '/extensions') }}

# --- Floorp extensions (download .xpi into profile) ---
{% for ext in floorp.extensions %}
{{ firefox_extension(ext, floorp_profile, require='floorp_extensions_dir', user=user) }}
{% endfor %}

# Remove extensions no longer wanted (list in data/floorp.yaml).
{% for ext_id in floorp.unwanted %}
{%- set safe_id = ext_id | replace('{', '') | replace('}', '') | replace('-', '_') | replace('@', '_') | replace('.', '_') %}
floorp_remove_{{ safe_id }}:
  file.absent:
    - name: {{ floorp_profile }}/extensions/{{ ext_id }}.xpi
{% endfor %}

# Remove extensions.json so Floorp rebuilds it on next launch,
# picking up extensions.autoDisableScopes=0 from user.js
floorp_reset_extensions_json:
  file.absent:
    - name: {{ floorp_profile }}/extensions.json
    - onchanges:
      - file: floorp_user_js
{% for ext in floorp.extensions %}
      - cmd: floorp_ext_{{ ext.slug | replace('-', '_') }}
{% endfor %}
