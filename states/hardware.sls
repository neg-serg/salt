{% from '_imports.jinja' import host %}
{% from '_macros_service.jinja' import udev_rule, service_with_unit %}

# --- Custom udev rules: I/O schedulers, audio devices, SATA ALPM ---
{{ udev_rule('custom_udev_rules', '/etc/udev/rules.d/99-custom.rules', source='salt://configs/udev-custom.rules') }}

# --- Fan control: auto-generate /etc/fancontrol from detected hwmon ---
{% if host.features.fancontrol %}

fancontrol_setup_script:
  file.managed:
    - name: /usr/local/bin/fancontrol-setup
    - source: salt://scripts/fancontrol-setup.sh
    - mode: '0755'

fancontrol_reapply_script:
  file.managed:
    - name: /etc/systemd/system-sleep/99-fancontrol-reapply
    - makedirs: True
    - mode: '0755'
    - source: salt://scripts/fancontrol-reapply.sh.j2
    - template: jinja
    - context:
        cpu_vendor: {{ host.cpu_vendor }}

{{ service_with_unit('fancontrol-setup', 'salt://units/fancontrol-setup.service.j2', template='jinja', context={'gpu_enable': host.cpu_vendor == 'amd'}, enabled=None) }}

{{ service_with_unit('fancontrol', 'salt://units/fancontrol.service', requires=['cmd: fancontrol-setup_daemon_reload', 'file: fancontrol_setup_script']) }}

# Load nct6775 kernel module for motherboard PWM fan control
nct6775_module:
  kmod.present:
    - name: nct6775

{% endif %}

# --- Mask rfkill on hosts without WiFi (avoids 5s+ timeout at boot) ---
{% if not host.features.network.wifi %}

rfkill_service_masked:
  service.masked:
    - name: systemd-rfkill.service

rfkill_socket_masked:
  service.masked:
    - name: systemd-rfkill.socket

{% endif %}
