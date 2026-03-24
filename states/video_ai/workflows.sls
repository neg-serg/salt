{% from '_imports.jinja' import host, user %}
{% import_yaml 'data/video_ai.yaml' as video_ai %}
{% set workflows_dir = host.mnt_one ~ '/video-ai/workflows' %}

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
{% if model.enabled and model.comfyui_workflow_i2v is defined %}
video_ai_workflow_i2v_{{ model.id | replace('-', '_') }}:
  file.managed:
    - name: {{ workflows_dir }}/{{ model.comfyui_workflow_i2v }}
    - source: salt://configs/video-ai/{{ model.comfyui_workflow_i2v }}
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - require:
      - file: video_ai_workflows_dir
{% endif %}
{% endfor %}

# ── Image workflow deployment ──────────────────────────────────────
{% for model in video_ai.get('image_models', []) %}
{% if model.enabled and model.comfyui_workflow is defined %}
video_ai_image_workflow_{{ model.id | replace('-', '_') }}:
  file.managed:
    - name: {{ workflows_dir }}/{{ model.comfyui_workflow }}
    - source: salt://configs/video-ai/{{ model.comfyui_workflow }}
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - require:
      - file: video_ai_workflows_dir
{% endif %}
{% if model.enabled and model.comfyui_workflow_i2i is defined %}
video_ai_image_workflow_i2i_{{ model.id | replace('-', '_') }}:
  file.managed:
    - name: {{ workflows_dir }}/{{ model.comfyui_workflow_i2i }}
    - source: salt://configs/video-ai/{{ model.comfyui_workflow_i2i }}
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0644'
    - require:
      - file: video_ai_workflows_dir
{% endif %}
{% endfor %}
