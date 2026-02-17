{% from 'host_config.jinja' import host %}
{% from '_macros_install.jinja' import firefox_extension %}
{% set user = host.user %}
{% set home = host.home %}
# Floorp browser: user.js + userChrome.css + userContent.css + extensions
{% if host.features.floorp %}
{% from 'packages.jinja' import floorp_extensions, unwanted_extensions %}

{% set floorp_profile = home ~ '/.floorp/c85pjaxk.default-default' %}

floorp_user_js:
  file.managed:
    - name: {{ floorp_profile }}/user.js
    - source: salt://dotfiles/dot_config/floorp/user.js
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

floorp_userchrome:
  file.managed:
    - name: {{ floorp_profile }}/chrome/userChrome.css
    - source: salt://dotfiles/dot_config/floorp/userChrome.css
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

floorp_usercontent:
  file.managed:
    - name: {{ floorp_profile }}/chrome/userContent.css
    - source: salt://dotfiles/dot_config/floorp/userContent.css
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

floorp_extensions_dir:
  file.directory:
    - name: {{ floorp_profile }}/extensions
    - user: {{ user }}
    - group: {{ user }}

# --- Floorp extensions (download .xpi into profile) ---
{% for ext in floorp_extensions %}
{{ firefox_extension(ext, floorp_profile, require='floorp_extensions_dir', user=user) }}
{% endfor %}

# Remove extensions no longer wanted (list in packages.jinja).
{% for ext_id in unwanted_extensions %}
floorp_remove_ext_{{ loop.index }}:
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
{% for ext in floorp_extensions %}
      - cmd: floorp_ext_{{ ext.slug | replace('-', '_') }}
{% endfor %}
{% endif %}
