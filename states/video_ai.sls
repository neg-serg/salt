{% from '_imports.jinja' import host, user, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/video_ai.yaml' as video_ai %}
# Video AI: ComfyUI + model management for local video generation (7900 XTX)
{% if host.features.get('video_ai', False) %}

{% set base_dir = host.mnt_one ~ '/video-ai' %}
{% set comfyui_dir = base_dir ~ '/comfyui' %}
{% set models_dir = base_dir ~ '/models' %}
{% set workflows_dir = base_dir ~ '/workflows' %}
{% set output_dir = base_dir ~ '/output' %}

# ── Directory structure ──────────────────────────────────────────────
{{ ensure_dir('video_ai_base_dir', base_dir, require=['mount: mount_one']) }}
{{ ensure_dir('video_ai_models_dir', models_dir, require=['file: video_ai_base_dir']) }}
{{ ensure_dir('video_ai_workflows_dir', workflows_dir, require=['file: video_ai_base_dir']) }}
{{ ensure_dir('video_ai_output_dir', output_dir, require=['file: video_ai_base_dir']) }}

# NOTE: ffmpeg is a system dep (already installed), ROCm is pulled by PyTorch
# wheels inside the venv (video-ai-setup.sh). No explicit pacman_install needed.

# ── ComfyUI installation (bootstrap script) ──────────────────────────
video_ai_comfyui_setup:
  cmd.script:
    - source: salt://scripts/video-ai-setup.sh
    - shell: /bin/bash
    - timeout: 3600
    - creates: {{ comfyui_dir }}/venv/bin/python
    - env:
      - COMFYUI_DIR: {{ comfyui_dir }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - file: video_ai_base_dir

# ── ComfyUI custom nodes ─────────────────────────────────────────────
{% for node in video_ai.get('comfyui_nodes', []) %}
video_ai_node_{{ node.dir | lower | replace('-', '_') }}:
  cmd.run:
    - name: git clone {{ node.repo }} {{ comfyui_dir }}/custom_nodes/{{ node.dir }}
    - creates: {{ comfyui_dir }}/custom_nodes/{{ node.dir }}
    - runas: {{ user }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: video_ai_comfyui_setup
{% endfor %}

# ── Model downloads ──────────────────────────────────────────────────
{% for model in video_ai.get('models', []) %}
{% if model.enabled %}
{{ ensure_dir('video_ai_model_dir_' ~ model.id | replace('-', '_'), models_dir ~ '/' ~ model.id, require=['file: video_ai_models_dir']) }}

{% for file in model.files %}
video_ai_download_{{ model.id | replace('-', '_') }}_{{ loop.index }}:
  cmd.run:
    - name: >-
        curl -fsSL -C -
        -o {{ models_dir }}/{{ model.id }}/{{ file }}
        "https://huggingface.co/{{ model.repo }}/resolve/main/{{ file }}"
    - creates: {{ models_dir }}/{{ model.id }}/{{ file }}
    - runas: {{ user }}
    - timeout: 14400
    - parallel: True
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - file: video_ai_model_dir_{{ model.id | replace('-', '_') }}
{% endfor %}

# Symlink model files into ComfyUI models directory
video_ai_symlink_{{ model.id | replace('-', '_') }}:
  file.symlink:
    - name: {{ comfyui_dir }}/models/checkpoints/{{ model.id }}
    - target: {{ models_dir }}/{{ model.id }}
    - user: {{ user }}
    - force: True
    - makedirs: True
    - require:
      - cmd: video_ai_comfyui_setup
      {% for file in model.files %}
      - cmd: video_ai_download_{{ model.id | replace('-', '_') }}_{{ loop.index }}
      {% endfor %}
{% endif %}
{% endfor %}

# ── Workflow deployment ──────────────────────────────────────────────
{% for model in video_ai.get('models', []) %}
{% if model.enabled and model.comfyui_workflow is defined %}
video_ai_workflow_{{ model.id | replace('-', '_') }}:
  file.managed:
    - name: {{ workflows_dir }}/{{ model.comfyui_workflow }}
    - source: salt://configs/video-ai/{{ model.comfyui_workflow }}
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - require:
      - file: video_ai_workflows_dir
{% endif %}
{% endfor %}

# ── Generation runner deployment ─────────────────────────────────────
video_ai_generate_script:
  file.managed:
    - name: {{ base_dir }}/generate.sh
    - source: salt://scripts/video-ai-generate.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - cmd: video_ai_comfyui_setup

{% endif %}
