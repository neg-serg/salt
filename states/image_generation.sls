{% from '_imports.jinja' import host, user, home, gopass_secret %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/image_providers.yaml' as image_providers_data %}
{% if host.features.get('image_gen', True) %}
{% set _image_gen_cfg = home ~ '/.config/image-gen/providers.yaml' %}

{# Resolve image provider API keys from gopass (free-tier providers).
   gopass fails in Salt daemon context (no GPG agent); AWK parses the existing
   rendered config as fallback.  First deploy: run scripts/bootstrap-image-providers.sh
   to seed the config, then subsequent `just` runs maintain keys via AWK. #}
{% set _image_providers = [] %}
{% for p in image_providers_data.get('providers', []) %}
  {% if p.gopass_key is defined %}
    {% set _awk_fallback = "awk '/name: \"" ~ p.name ~ "\"/{f=1} f && /api_key:/{gsub(/.*api_key:[[:space:]]*\"?/,\"\"); gsub(/\"[[:space:]]*$/,\"\"); print; exit}' " ~ _image_gen_cfg ~ " 2>/dev/null || true" %}
    {% set _key = gopass_secret(p.gopass_key, _awk_fallback) %}
  {% else %}
    {% set _key = p.get('dummy_key', '') %}
  {% endif %}
  {% if _key %}
    {% set _provider = {'name': p.name, 'base_url': p.base_url, 'api_type': p.api_type, 'api_key': _key, 'priority': p.priority, 'models': p.models} %}
    {% if p.account_id is defined and p.account_id %}
      {% do _provider.update({'account_id': p.account_id}) %}
    {% endif %}
    {% do _image_providers.append(_provider) %}
  {% endif %}
{% endfor %}

{{ ensure_dir('image_gen_config_dir', home ~ '/.config/image-gen') }}
image_gen_providers_config:
  file.managed:
    - name: {{ _image_gen_cfg }}
    - source: salt://configs/image-gen-providers.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        providers: {{ _image_providers | tojson }}
    - require:
      - file: image_gen_config_dir
{% endif %}
