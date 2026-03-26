{% from '_imports.jinja' import host, home %}
{% from '_macros_desktop.jinja' import dconf_settings %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit %}
{% import_yaml 'data/desktop.yaml' as desktop %}

# --- SSH directory setup ---
{{ ensure_dir('ssh_dir', home ~ '/.ssh', mode='0700') }}

# --- dconf: GTK/icon/font theme for Wayland apps ---
{{ dconf_settings('dconf_themes', desktop.dconf_settings) }}

# --- Salt daemon systemd unit ---
salt_daemon_venv_ready:
  file.exists:
    - name: {{ host.project_dir }}/.venv/bin/python3

{{ service_with_unit('salt-daemon', 'salt://units/salt-daemon.service.j2', template='jinja', context={'project_dir': host.project_dir, 'runtime_dir': host.runtime_dir}, running=True, requires=['file: salt_daemon_venv_ready']) }}
