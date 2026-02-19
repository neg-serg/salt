{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit, service_with_healthcheck %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% import_yaml 'data/ollama.yaml' as ollama %}
# Ollama LLM server: systemd service, model pulls
{% if host.features.ollama %}

{{ service_with_unit('ollama', 'salt://units/ollama.service', template='jinja', context={'user': user, 'home': home}, onlyif='command -v ollama') }}

{{ ensure_dir('ollama_models_dir', host.mnt_one ~ '/ollama/models', require=['mount: mount_one']) }}

{{ service_with_healthcheck('ollama_start', 'ollama', 'curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1', requires=['service: ollama_enabled']) }}

{% for model in ollama.models %}
pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}:
  cmd.run:
    - name: |
        response=$(curl -sS --max-time 600 \
          -X POST http://127.0.0.1:11434/api/pull \
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
        curl -sf http://127.0.0.1:11434/api/tags |
        rg -q '"{{ model }}"'
    - timeout: 660
    - require:
      - cmd: ollama_start
{% endfor %}

# --- openclaw (local AI assistant agent) ---
{{ npm_pkg('openclaw', user=user, home=home) }}
{% endif %}
