{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit %}
{% from '_macros_install.jinja' import http_file %}
{% import_yaml 'data/llama_embed.yaml' as embed %}
# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan
# Service is NOT enabled at boot (manual_start) — VRAM is shared with desktop GPU.
{% set models_dir = host.mnt_one ~ '/llama-embed/models' %}
{% set model_path = models_dir ~ '/' ~ embed.file %}
{% set port = catalog.llama_embed.port %}

{{ paru_install('llama_cpp_vulkan', 'llama.cpp-vulkan') }}

{{ ensure_dir('llama_embed_models_dir', models_dir, require=['mount: mount_one']) }}

{{ http_file('llama_embed_model', 'https://huggingface.co/' ~ embed.repo ~ '/resolve/main/' ~ embed.file, model_path, user=user, require=['file: llama_embed_models_dir'], parallel=False, version=embed.file, cache=False) }}

{{ service_with_unit('llama_embed', 'salt://units/llama-embed.service', template='jinja', context={'user': user, 'home': home, 'models_dir': models_dir, 'model_file': embed.file, 'port': port, 'context': embed.context, 'gpu_layers': embed.gpu_layers, 'pooling': embed.pooling}, requires=['cmd: llama_embed_model', 'cmd: install_llama_cpp_vulkan'], enabled=False) }}
