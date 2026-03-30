{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_desktop.jinja' import browser_extensions %}
# Zen Browser: user.js + userChrome.css + extensions for the primary managed browser path
{% if host.zen_profile %}
{% import_yaml 'data/zen_browser.yaml' as zen %}
{% set zen_profile = home ~ '/.config/zen/' ~ host.zen_profile %}
{% set floorp_profile = home ~ '/.floorp/' ~ host.floorp_profile %}
{% set zen_migration_dir = zen_profile ~ '/.migrations' %}
{% set zen_floorp_import_stamp = zen_migration_dir ~ '/floorp-profile-import-v1' %}
zen_user_js:
  file.managed:
    - name: {{ zen_profile }}/user.js
    - source: salt://dotfiles/dot_config/zen-browser/user.js
    - template: jinja
    - context:
        home: {{ home }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

zen_userchrome:
  file.managed:
    - name: {{ zen_profile }}/chrome/userChrome.css
    - source: salt://dotfiles/dot_config/zen-browser/userChrome.css
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{{ ensure_dir('zen_migration_dir', zen_migration_dir) }}

{% if host.get('migrate_floorp_profile_to_zen', false) and host.features.floorp and host.floorp_profile %}
zen_floorp_profile_import:
  cmd.run:
    - name: >
        {{ home }}/src/salt/scripts/migrate-floorp-to-zen-profile.sh
        --floorp-profile {{ floorp_profile | yaml_dquote }}
        --zen-profile {{ zen_profile | yaml_dquote }}
        --stamp {{ zen_floorp_import_stamp | yaml_dquote }}
    - creates: {{ zen_floorp_import_stamp }}
    - require:
      - file: zen_migration_dir
      - file: zen_user_js
      - file: zen_userchrome
      - file: floorp_user_js
{% endif %}

{{ browser_extensions('zen', zen_profile, zen.extensions, 'zen_user_js') }}
{% endif %}
