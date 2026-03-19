{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval, ollama_pull_timeout %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit, service_with_healthcheck %}
{% import_yaml 'data/ollama.yaml' as ollama %}
# Ollama LLM server: systemd service, model pulls
{{ service_with_unit('ollama', 'salt://units/ollama.service.j2', template='jinja', context={'user': user, 'home': home, 'mnt_one': host.mnt_one, 'ollama_port': catalog.ollama.port}, onlyif='command -v ollama') }}

{{ ensure_dir('ollama_models_dir', host.mnt_one ~ '/ollama/models', require=['mount: mount_one']) }}

{% set ollama_base = '127.0.0.1:' ~ catalog.ollama.port %}
{{ service_with_healthcheck('ollama_start', 'ollama', catalog=catalog, requires=['service: ollama_enabled']) }}

{% for model in ollama.models %}
pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}:
  cmd.run:
    - name: ollama pull {{ model }}
    - unless: >-
        curl -sf http://{{ ollama_base }}/api/tags |
        rg -q '"{{ model }}[":]'
    - timeout: {{ ollama_pull_timeout }}
    - parallel: True
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: ollama_start
{% endfor %}
