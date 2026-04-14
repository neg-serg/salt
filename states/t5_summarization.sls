{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit, container_service %}
{% from '_macros_install.jinja' import huggingface_file %}
{% import_yaml 'data/t5_summarization.yaml' as t5 %}
# llama.cpp T5 summarization server: UrukHan/t5-russian-summarization via Vulkan.
# Downloads safetensors from HuggingFace, converts to GGUF, serves via llama-server.
# Service is NOT enabled at boot (manual_start) — VRAM is shared with desktop GPU.
#
# Feature 087-containerize-services: branches on host.features.containers.t5_summarization.
#   false (default) → native llama.cpp-vulkan + systemd unit template
#   true             → containerized via Podman Quadlet (Vulkan device passthrough)
{% set _containerized = host.features.get('containers', {}).get('t5_summarization', False) %}
{% set models_dir = host.mnt_one ~ '/t5-summarization/models' %}
{% set hf_path = models_dir ~ '/hf' %}
{% set hf_file = t5.hf_file %}
{% set gguf_path = models_dir ~ '/' ~ t5.gguf_file %}
{% set port = catalog.t5_summarization.port %}

{{ ensure_dir('t5_summarization_models_dir', models_dir, require=['mount: mount_one']) }}
{{ ensure_dir('t5_summarization_hf_dir', hf_path, require=['mount: mount_one']) }}

# Download safetensors from HuggingFace (unconditional — feeds both native and containerized)
{{ huggingface_file('t5_summarization_model', t5.hf_repo, hf_file, hf_path ~ '/' ~ hf_file, user=user, require=['file: t5_summarization_hf_dir'], parallel=False, version=hf_file, cache=False) }}

# Download tokenizer files (required by convert_hf_to_gguf.py)
{{ huggingface_file('t5_summarization_tokenizer_config', t5.hf_repo, 'tokenizer_config.json', hf_path ~ '/tokenizer_config.json', user=user, require=['file: t5_summarization_hf_dir'], parallel=False, cache=False) }}
{{ huggingface_file('t5_summarization_special_tokens', t5.hf_repo, 'special_tokens_map.json', hf_path ~ '/special_tokens_map.json', user=user, require=['file: t5_summarization_hf_dir'], parallel=False, cache=False) }}
{{ huggingface_file('t5_summarization_spiece', t5.hf_repo, 'spiece.model', hf_path ~ '/spiece.model', user=user, require=['file: t5_summarization_hf_dir'], parallel=False, cache=False) }}
{{ huggingface_file('t5_summarization_tokenizer', t5.hf_repo, 'tokenizer.json', hf_path ~ '/tokenizer.json', user=user, require=['file: t5_summarization_hf_dir'], parallel=False, cache=False) }}
{{ huggingface_file('t5_summarization_config', t5.hf_repo, 'config.json', hf_path ~ '/config.json', user=user, require=['file: t5_summarization_hf_dir'], parallel=False, cache=False) }}

# Convert safetensors → GGUF (guarded by GGUF file existence)
t5_summarization_convert:
  cmd.run:
    - name: |
        cd {{ hf_path }}
        /usr/bin/convert_hf_to_gguf.py {{ hf_path }} --outfile {{ gguf_path }} --outtype q5_k_m 2>&1
    - runas: {{ user }}
    - creates: {{ gguf_path }}
    - require:
      - cmd: t5_summarization_model
      - cmd: t5_summarization_tokenizer_config
      - cmd: t5_summarization_special_tokens
      - cmd: t5_summarization_spiece
      - cmd: t5_summarization_tokenizer
      - cmd: t5_summarization_config

{% if _containerized %}
# ── Containerized form (Podman Quadlet) ────────────────────────────────
t5_summarization_native_unit_absent:
  file.absent:
    - name: /etc/systemd/system/t5_summarization.service

t5_summarization_native_unit_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: t5_summarization_native_unit_absent

{{ container_service('t5_summarization', catalog.t5_summarization, image_registry,
    requires=['file: t5_summarization_hf_dir', 'cmd: t5_summarization_convert', 'cmd: t5_summarization_native_unit_daemon_reload']) }}
{% else %}
# ── Native form ────────────────────────────────────────────────────────
{{ paru_install('llama_cpp_vulkan', 'llama.cpp-vulkan') }}
{{ paru_install('python_transformers', 'python-transformers') }}

{{ service_with_unit('t5_summarization', 'salt://units/t5-summarization.service', template='jinja', context={'user': user, 'home': home, 'models_dir': models_dir, 'gguf_file': t5.gguf_file, 'context': t5.context, 'gpu_layers': t5.gpu_layers, 'port': port}, requires=['cmd: t5_summarization_convert', 'cmd: install_llama_cpp_vulkan', 'cmd: install_python_transformers'], enabled=False) }}

# Rollback cleanup: if containers.t5_summarization flips back to false
t5_summarization_quadlet_absent:
  file.absent:
    - name: /etc/containers/systemd/t5_summarization.container
{% endif %}
