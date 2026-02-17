{% from 'host_config.jinja' import host %}
{% from '_macros_service.jinja' import service_with_unit %}
{% from '_macros_pkg.jinja' import npm_pkg %}
{% set user = host.user %}
{% set home = host.home %}
# Ollama LLM server: systemd service, model pulls
{% if host.features.ollama %}

{{ service_with_unit('ollama', 'salt://units/ollama.service', template='jinja', context={'user': user, 'home': home}, onlyif='command -v ollama') }}

ollama_models_dir:
  file.directory:
    - name: /mnt/one/ollama/models
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
    - require:
      - mount: mount_one

ollama_start:
  cmd.run:
    - name: |
        systemctl daemon-reload
        systemctl restart ollama
        for i in $(seq 1 30); do
          curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && exit 0
          sleep 1
        done
        echo "ollama failed to start within 30s" >&2
        exit 1
    - shell: /bin/bash
    - unless: curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1
    - require:
      - service: ollama_enabled

{% for model in ['deepseek-r1:8b', 'llama3.2:3b', 'qwen2.5-coder:7b'] %}
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
        grep -q '"{{ model }}"'
    - timeout: 660
    - require:
      - cmd: ollama_start
{% endfor %}

# --- openclaw (local AI assistant agent) ---
{{ npm_pkg('openclaw', user=user, home=home) }}
{% endif %}
