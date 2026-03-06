{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval, service_ports, ollama_pull_timeout %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit, service_with_healthcheck %}
{% import_yaml 'data/ollama.yaml' as ollama %}
# Ollama LLM server: systemd service, model pulls
{% if host.features.ollama %}

{{ service_with_unit('ollama', 'salt://units/ollama.service', template='jinja', context={'user': user, 'home': home, 'mnt_one': host.mnt_one, 'ollama_port': service_ports.ollama.port}, onlyif='command -v ollama') }}

{{ ensure_dir('ollama_models_dir', host.mnt_one ~ '/ollama/models', require=['mount: mount_one']) }}

{% set ollama_base = '127.0.0.1:' ~ service_ports.ollama.port %}
{{ service_with_healthcheck('ollama_start', 'ollama', 'curl -sf http://' ~ ollama_base ~ service_ports.ollama.healthcheck ~ ' >/dev/null 2>&1', requires=['service: ollama_enabled']) }}

{% for model in ollama.models %}
pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}:
  cmd.run:
    - name: |
        response=$(curl -sS --max-time {{ ollama_pull_timeout - 60 }} \
          -X POST http://{{ ollama_base }}/api/pull \
          -d '{"name": "{{ model }}", "stream": false}')
        status=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null)
        if [ "$status" = "success" ]; then
          echo "{{ model }}: pulled successfully"
        else
          echo "{{ model }}: pull failed" >&2
          echo "$response" >&2
          exit 1
        fi
    - shell: /bin/bash
    - unless: >-
        curl -sf http://{{ ollama_base }}/api/tags |
        rg -q '"{{ model }}"'
    - timeout: {{ ollama_pull_timeout }}
    - parallel: True
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: ollama_start
{% endfor %}
{% endif %}
