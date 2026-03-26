{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_install.jinja' import firefox_extension %}
# Zen Browser: user.js + userChrome.css + extensions for the primary managed browser path
{% if host.zen_profile %}
{% import_yaml 'data/zen_browser.yaml' as zen %}
{% set zen_profile = home ~ '/.config/zen/' ~ host.zen_profile %}
{% set floorp_profile = home ~ '/.floorp/' ~ host.floorp_profile %}
{% set zen_migration_dir = zen_profile ~ '/.migrations' %}
{% set zen_floorp_import_stamp = zen_migration_dir ~ '/floorp-profile-import-v1' %}
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

zen_supergradient_theme:
  file.recurse:
    - name: {{ zen_profile }}/chrome/zen-themes/af7ee14f-e9d4-4806-8438-c59b02b77715
    - source: salt://dotfiles/dot_config/zen-browser/zen-themes/af7ee14f-e9d4-4806-8438-c59b02b77715
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

{{ ensure_dir('zen_extensions_dir', zen_profile ~ '/extensions') }}
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

# --- Zen Browser extensions (download .xpi into profile) ---
{% for ext in zen.extensions %}
{{ firefox_extension(ext, zen_profile, require='zen_extensions_dir', user=user, prefix='zen_ext') }}
{% endfor %}

# Remove extensions.json so Zen rebuilds it on next launch,
# picking up extensions.autoDisableScopes=0 from user.js and any extension payload updates.
zen_reset_extensions_json:
  file.absent:
    - name: {{ zen_profile }}/extensions.json
    - onchanges:
      - file: zen_user_js
{% for ext in zen.extensions %}
      - cmd: zen_ext_{{ ext.slug | replace('-', '_') }}
{% endfor %}
{% endif %}
