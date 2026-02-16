{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload, service_with_unit %}

# --- Custom udev rules: I/O schedulers, audio devices, SATA ALPM ---
custom_udev_rules:
  file.managed:
    - name: /etc/udev/rules.d/99-custom.rules
    - source: salt://configs/udev-custom.rules
    - mode: '0644'

udev_reload_custom:
  cmd.run:
    - name: udevadm control --reload-rules && udevadm trigger
    - onchanges:
      - file: custom_udev_rules

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
        cpu_vendor: {{ host.get('cpu_vendor', '') }}

{{ service_with_unit('fancontrol-setup', 'salt://units/fancontrol-setup.service.j2', template='jinja', context={'gpu_enable': 'true' if host.get('cpu_vendor', '') == 'amd' else 'false'}, enabled=None) }}

{{ service_with_unit('fancontrol', 'salt://units/fancontrol.service', requires=['cmd: fancontrol-setup_daemon_reload', 'file: fancontrol_setup_script']) }}

# Load nct6775 kernel module for motherboard PWM fan control
nct6775_module:
  kmod.present:
    - name: nct6775

{% endif %}

# --- Mask rfkill on hosts without WiFi (avoids 5s+ timeout at boot) ---
{% if not host.features.network.wifi %}

mask_rfkill_service:
  service.masked:
    - name: systemd-rfkill.service

mask_rfkill_socket:
  service.masked:
    - name: systemd-rfkill.socket

{% endif %}
