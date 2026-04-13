# Group: AI/ML services — agents, LLM inference, image generation
# Usage: just apply group/ai
{% from '_imports.jinja' import host %}

include:
{% if host.features.ollama %}
  - ollama
{% endif %}
{% if host.features.llama_embed %}
  - llama_embed
{% endif %}
{% if host.features.get('nanoclaw', false) %}
  - nanoclaw
{% endif %}
{% if host.features.get('telethon_bridge', false) %}
  - telethon_bridge
{% endif %}
{% if host.features.get('image_gen', True) %}
  - image_generation
{% endif %}
{% if host.features.opencode %}
  - opencode
{% endif %}
{% if host.features.get('opencode_telegram', false) %}
  - opencode_telegram
{% endif %}
{% if host.features.get('video_ai', False) %}
  - video_ai
{% endif %}
{% if host.features.get('t5_summarization', false) %}
  - t5_summarization
{% endif %}
