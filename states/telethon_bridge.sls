{% from '_imports.jinja' import host, user, home, proxypilot_key, tg_secret %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% import_yaml 'data/container_images.yaml' as image_registry %}
{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, user_service_enable, user_service_file, container_service %}
{% import_yaml 'data/versions.yaml' as ver %}
# Feature 087-containerize-services: branches on features.containers.telethon_bridge.
# While container_images.yaml[telethon_bridge].digest is null (research Decision 7,
# upstream-image gate), the container_service macro emits only a _container_deferred
# no-op state and the native deployment path continues unchanged — flipping the
# toggle has no runtime effect until a first-party upstream image is identified.
{% set _containerized = host.features.get('containers', {}).get('telethon_bridge', False) %}
# ── Secret resolution ─────────────────────────────────────────────────
{% set _proxy_key = proxypilot_key() %}
{% set _tb_creds = home ~ '/.telethon-bridge/credentials' %}
{% set _api_id = tg_secret('api/telegram-telethon-id', 'api-id', cred_base=_tb_creds) %}
{% set _api_hash = tg_secret('api/telegram-telethon-hash', 'api-hash', cred_base=_tb_creds) %}
{% set _telegram_uid = tg_secret('api/openclaw-telegram-uid', 'telegram-uid') %}
{% set _telegram_uid_levra = tg_secret('api/telegram-uid-levra', 'telegram-uid-levra') %}
{% set _telegram_uid_guest2 = tg_secret('api/telegram-uid-guest2', 'telegram-uid-guest2') %}

# ── Install python-telethon from AUR ─────────────────────────────────
{{ paru_install('python_telethon', 'python-telethon', version=ver.telethon) }}

# ── Directories ──────────────────────────────────────────────────────
{{ ensure_dir('telethon_bridge_dir', home ~ '/.telethon-bridge') }}
{{ ensure_dir('telethon_bridge_credentials_dir', home ~ '/.telethon-bridge/credentials', mode='0700') }}
{{ ensure_dir('telethon_bridge_media_dir', home ~ '/.telethon-bridge/media') }}

# ── Deploy config (secrets injected at apply time) ────────────────────
telethon_bridge_config:
  file.managed:
    - name: {{ home }}/.telethon-bridge/config.yaml
    - source: salt://configs/telethon-bridge.yaml.j2
    - template: jinja
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0600'
    - context:
        home: {{ home }}
        api_id: {{ _api_id | tojson }}
        api_hash: {{ _api_hash | tojson }}
        proxy_key: {{ _proxy_key | tojson }}
        telegram_uid: {{ _telegram_uid | tojson }}
        telegram_uid_levra: {{ _telegram_uid_levra | tojson }}
        telegram_uid_guest2: {{ _telegram_uid_guest2 | tojson }}
    - require:
      - file: telethon_bridge_dir

# ── Deploy bridge script ─────────────────────────────────────────────
telethon_bridge_script:
  file.managed:
    - name: {{ home }}/.local/bin/telethon-bridge
    - source: salt://scripts/telethon-bridge.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'

# ── Deploy init script ──────────────────────────────────────────────
telethon_bridge_init_script:
  file.managed:
    - name: {{ home }}/.local/bin/telethon-bridge-init
    - source: salt://scripts/telethon-bridge-init.py
    - user: {{ user }}
    - group: {{ user }}
    - mode: '0755'
    - require:
      - file: telethon_bridge_config

# ── Systemd user service ─────────────────────────────────────────────
{{ user_service_file('telethon_bridge_service', 'telethon-bridge.service') }}

{{ user_service_enable('telethon_bridge_enabled', start_now=['telethon-bridge.service'], requires=['cmd: install_python_telethon', 'file: telethon_bridge_config', 'file: telethon_bridge_script', 'file: telethon_bridge_service']) }}

{% if _containerized %}
# ── Containerized form (Podman Quadlet, user scope, digest-gated) ──
# While container_images.yaml[telethon_bridge].digest is null, this call
# emits only a test.succeed_without_changes state as a visible gate marker;
# when a digest is eventually committed, it will emit the full state graph
# and the native user_service_enable above will need to be gated on
# `not _containerized` in a follow-up commit.
{{ container_service('telethon_bridge', catalog.telethon_bridge, image_registry,
    user_scope=True,
    requires=['cmd: install_python_telethon', 'file: telethon_bridge_config']) }}
{% else %}
telethon_bridge_quadlet_absent:
  file.absent:
    - name: {{ home }}/.config/containers/systemd/telethon-bridge.container
{% endif %}
