{% from '_imports.jinja' import host, user, home, service_ports %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit, service_with_healthcheck %}
{% from '_macros_install.jinja' import http_file %}
{% import_yaml 'data/llama_embed.yaml' as embed %}
# llama.cpp embedding server: Qwen3-Embedding-8B via Vulkan
{% if host.features.llama_embed %}

{% set models_dir = host.mnt_one ~ '/llama-embed/models' %}
{% set model_path = models_dir ~ '/' ~ embed.file %}
{% set port = service_ports.llama_embed.port %}

{{ paru_install('llama_cpp_vulkan', 'llama.cpp-vulkan') }}

{{ ensure_dir('llama_embed_models_dir', models_dir, require=['mount: mount_one']) }}

{{ http_file('llama_embed_model', 'https://huggingface.co/' ~ embed.repo ~ '/resolve/main/' ~ embed.file, model_path, user=user, require=['file: llama_embed_models_dir'], parallel=False, version=embed.file, cache=False) }}

{{ service_with_unit('llama_embed', 'salt://units/llama-embed.service', template='jinja', context={'user': user, 'home': home, 'models_dir': models_dir, 'model_file': embed.file, 'port': port, 'context': embed.context, 'gpu_layers': embed.gpu_layers, 'pooling': embed.pooling}, requires=['cmd: llama_embed_model', 'cmd: install_llama_cpp_vulkan'], onlyif='command -v llama-server') }}

{{ service_with_healthcheck('llama_embed_start', 'llama_embed', 'curl -sf http://127.0.0.1:' ~ port ~ service_ports.llama_embed.healthcheck ~ ' >/dev/null 2>&1', timeout=90, requires=['service: llama_embed_enabled']) }}

{% endif %}
