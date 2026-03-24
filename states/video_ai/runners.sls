{% from '_imports.jinja' import host, user %}
{% set base_dir = host.mnt_one ~ '/video-ai' %}

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

video_ai_generate_image_script:
  file.managed:
    - name: {{ base_dir }}/generate-image.sh
    - source: salt://scripts/video-ai-generate-image.sh
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - cmd: video_ai_comfyui_setup
