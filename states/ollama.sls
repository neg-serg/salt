{% from '_imports.jinja' import host, user, home, retry_attempts, retry_interval, ollama_pull_timeout %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit, container_service %}
{% import_yaml 'data/ollama.yaml' as ollama %}
# Ollama LLM server: systemd service + model pulls.
# Service is NOT enabled at boot (manual_start) — VRAM is shared with desktop GPU.
# Salt starts ollama temporarily for model pulls, then stops it.
#
# Feature 087-containerize-services: branches on host.features.containers.ollama.
#   false (default) → native ollama.service.j2 via service_with_unit
#   true             → containerized via Podman Quadlet via container_service
#                      with HTTP API model pulls (H1 fix — no host ollama binary)
{% set _containerized = host.features.get('containers', {}).get('ollama', False) %}

{{ ensure_dir('ollama_models_dir', host.mnt_one ~ '/ollama/models', require=['mount: mount_one']) }}

{% if _containerized %}
# ── Containerized form (Podman Quadlet) ────────────────────────────────
# In-place cutover: remove the native systemd unit file so the
# Quadlet-generated unit at /run/systemd/system/ollama.service is no
# longer shadowed by /etc/systemd/system/ollama.service (which takes
# precedence in systemd's search order). Without this cleanup, a
# `systemctl start ollama` would still hit the native binary even
# though the Quadlet file is deployed. Salt's file.managed never
# proactively removes files written by previous applies, so the
# cleanup must be explicit.
ollama_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/ollama.service

ollama_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: ollama_native_unit_absent

{{ container_service('ollama', catalog.ollama, image_registry,
    requires=['file: ollama_models_dir', 'mount: mount_one', 'cmd: ollama_native_unit_daemon_reload']) }}
{% else %}
# ── Native form ────────────────────────────────────────────────────────
{{ service_with_unit('ollama', 'salt://units/ollama.service.j2', template='jinja', context={'user': user, 'home': home, 'mnt_one': host.mnt_one, 'ollama_port': catalog.ollama.port}, enabled=False) }}

# Rollback cleanup: if the containers.ollama flag flips back to false,
# make sure the Quadlet unit file is gone so systemd doesn't keep a ghost
# unit alongside the native service.
ollama_quadlet_absent:
  file.absent:
    - name: /etc/containers/systemd/ollama.container
{% endif %}

{% set ollama_base = '127.0.0.1:' ~ catalog.ollama.port %}
{% set manifests = host.mnt_one ~ '/ollama/models/manifests/registry.ollama.ai' %}

{# Resolve manifest path: "model:tag" → library/model/tag, "ns/model:tag" → ns/model/tag.
   Models without explicit tag default to "latest". #}
{%- macro manifest_path(model) -%}
{%- set parts = model.split(':') -%}
{%- set name = parts[0] -%}
{%- set tag = parts[1] if parts | length > 1 else 'latest' -%}
{%- if '/' in name -%}
{{ manifests }}/{{ name }}/{{ tag }}
{%- else -%}
{{ manifests }}/library/{{ name }}/{{ tag }}
{%- endif -%}
{%- endmacro -%}

# Temporarily start ollama for model pulls (skipped when all manifests present).
# Works for both native and containerized — `systemctl start ollama` brings up
# either the pacman-installed ollama.service or the Quadlet-generated one.
ollama_tmp_start:
  cmd.run:
    - name: |
        systemctl start ollama
        for i in $(seq 1 30); do
          curl -sf http://{{ ollama_base }}/api/tags >/dev/null 2>&1 && exit 0
          sleep 1
        done
        echo "ollama failed to start within 30s" >&2; exit 1
    - unless: {% for model in ollama.models %}test -f "{{ manifest_path(model) }}" && {% endfor %}true
    - require:
      - cmd: ollama_daemon_reload

{% for model in ollama.models %}
pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}:
  cmd.run:
{% if _containerized %}
    # H1 fix: when containerized, there is no host `ollama` binary to call.
    # Pull via the HTTP API POST /api/pull, which writes manifest files into
    # the bind-mounted /mnt/one/ollama/models directory exactly as the
    # native binary would — the `unless:` manifest check still works.
    - name: >-
        curl -sf -X POST http://{{ ollama_base }}/api/pull
        -H 'Content-Type: application/json'
        -d '{"name":"{{ model }}","stream":false}'
{% else %}
    - name: ollama pull {{ model }}
{% endif %}
    - unless: test -f "{{ manifest_path(model) }}"
    - timeout: {{ ollama_pull_timeout }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: ollama_tmp_start
{% if host.features.network.get('zapret2', false) %}
      - service: zapret2_running
{% endif %}
{% endfor %}

# Stop ollama after model pulls to free VRAM.
# `systemctl stop ollama` works for both native and Quadlet-generated units.
ollama_tmp_stop:
  cmd.run:
    - name: systemctl stop ollama
    - onlyif: systemctl is-active ollama
    - require:
{% for model in ollama.models %}
      - cmd: pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}
{% endfor %}
