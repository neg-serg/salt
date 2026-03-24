{% from '_imports.jinja' import host, user, retry_attempts, retry_interval %}
{% from '_macros_service.jinja' import ensure_dir %}
{% import_yaml 'data/video_ai.yaml' as video_ai %}
{% set base_dir = host.mnt_one ~ '/video-ai' %}
{% set comfyui_dir = base_dir ~ '/comfyui' %}
{% set models_dir = base_dir ~ '/models' %}
{% set workflows_dir = base_dir ~ '/workflows' %}
{% set output_dir = base_dir ~ '/output' %}
{% set images_dir = base_dir ~ '/images' %}

# Video AI: ComfyUI + model management for local video generation (7900 XTX)

# ── Directory structure ──────────────────────────────────────────────
{{ ensure_dir('video_ai_base_dir', base_dir, require=['mount: mount_one']) }}
{{ ensure_dir('video_ai_models_dir', models_dir, require=['file: video_ai_base_dir']) }}
{{ ensure_dir('video_ai_workflows_dir', workflows_dir, require=['file: video_ai_base_dir']) }}
{{ ensure_dir('video_ai_output_dir', output_dir, require=['file: video_ai_base_dir']) }}
{{ ensure_dir('video_ai_images_dir', images_dir, require=['file: video_ai_base_dir']) }}

# NOTE: ffmpeg is a system dep (already installed), ROCm is pulled by PyTorch
# wheels inside the venv (video-ai-setup.sh). No explicit pacman_install needed.

# ── ComfyUI installation (bootstrap script) ──────────────────────────
video_ai_comfyui_chown:
  cmd.run:
    - name: chown -R {{ user }}:{{ user }} {{ comfyui_dir }}
    - onlyif: test -d {{ comfyui_dir }} && test "$(stat -c %U {{ comfyui_dir }})" = "root"

video_ai_comfyui_setup:
  cmd.script:
    - source: salt://scripts/video-ai-setup.sh
    - shell: /bin/bash
    - runas: {{ user }}
    - timeout: 3600
    - creates: {{ comfyui_dir }}/venv/bin/python
    - env:
      - COMFYUI_DIR: {{ comfyui_dir }}
      - GIT_CONFIG_GLOBAL: /dev/null
      - GIT_CONFIG_NOSYSTEM: '1'
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - file: video_ai_base_dir
      - cmd: video_ai_comfyui_chown

# ── ComfyUI custom nodes ─────────────────────────────────────────────
{% for node in video_ai.get('comfyui_nodes', []) %}
video_ai_node_{{ node.dir | lower | replace('-', '_') }}:
  cmd.run:
    - name: git clone {{ node.repo }} {{ comfyui_dir }}/custom_nodes/{{ node.dir }}
    - creates: {{ comfyui_dir }}/custom_nodes/{{ node.dir }}
    - runas: {{ user }}
    - env:
      - GIT_CONFIG_GLOBAL: /dev/null
      - GIT_CONFIG_NOSYSTEM: '1'
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: video_ai_comfyui_setup
{% endfor %}
