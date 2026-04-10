{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit, container_service %}
{% from '_macros_install.jinja' import http_file %}
{% import_yaml 'data/llama_embed.yaml' as embed %}
# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan.
# Service is NOT enabled at boot (manual_start) — VRAM is shared with desktop GPU.
#
# Feature 087-containerize-services: branches on host.features.containers.llama_embed.
#   false (default) → native llama.cpp-vulkan + systemd unit template
#   true             → containerized via Podman Quadlet (Vulkan device passthrough)
{% set _containerized = host.features.get('containers', {}).get('llama_embed', False) %}
{% set models_dir = host.mnt_one ~ '/llama-embed/models' %}
{% set model_path = models_dir ~ '/' ~ embed.file %}
{% set port = catalog.llama_embed.port %}

{{ ensure_dir('llama_embed_models_dir', models_dir, require=['mount: mount_one']) }}

# Model download is unconditional — the same GGUF file feeds both the native
# and containerized forms via the bind-mount.
{{ http_file('llama_embed_model', 'https://huggingface.co/' ~ embed.repo ~ '/resolve/main/' ~ embed.file, model_path, user=user, require=['file: llama_embed_models_dir'], parallel=False, version=embed.file, cache=False) }}

{% if _containerized %}
# ── Containerized form (Podman Quadlet) ────────────────────────────────
# In-place cutover: remove the native systemd unit file so the
# Quadlet-generated unit is no longer shadowed by the pacman-deployed
# /etc/systemd/system/llama_embed.service. See ollama.sls for the
# detailed rationale — same pattern.
llama_embed_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/llama_embed.service

llama_embed_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: llama_embed_native_unit_absent

{{ container_service('llama_embed', catalog.llama_embed, image_registry,
    requires=['file: llama_embed_models_dir', 'cmd: llama_embed_model', 'cmd: llama_embed_native_unit_daemon_reload']) }}
{% else %}
# ── Native form ────────────────────────────────────────────────────────
{{ paru_install('llama_cpp_vulkan', 'llama.cpp-vulkan') }}

{{ service_with_unit('llama_embed', 'salt://units/llama-embed.service', template='jinja', context={'user': user, 'home': home, 'models_dir': models_dir, 'model_file': embed.file, 'port': port, 'context': embed.context, 'gpu_layers': embed.gpu_layers, 'pooling': embed.pooling}, requires=['cmd: llama_embed_model', 'cmd: install_llama_cpp_vulkan'], enabled=False) }}

# Rollback cleanup: if containers.llama_embed flips back to false, ensure
# the Quadlet unit file is removed so systemd doesn't carry a ghost unit.
llama_embed_quadlet_absent:
  file.absent:
    - name: /etc/containers/systemd/llama-embed.container
{% endif %}
