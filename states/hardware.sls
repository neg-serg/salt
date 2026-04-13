{% from '_imports.jinja' import host %}
{% from '_macros_service.jinja' import udev_rule, service_with_unit %}

# --- RME USB device trigger script (deploys before udev rule can fire) ---
rme_usb_trigger_script:
  file.managed:
    - name: /usr/local/bin/rme-usb-trigger
    - source: salt://scripts/rme-usb-trigger.sh
    - mode: '0755'

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

# Load nct6775 when the current kernel exposes it; some kernels omit the
# module entirely, and that should not block the whole rollout.
nct6775_module:
  cmd.run:
    - name: |
        if lsmod | awk '{print $1}' | grep -Fxq nct6775; then
          echo "changed=no comment='nct6775 already loaded'"
        elif modinfo nct6775 >/dev/null 2>&1; then
          modprobe nct6775
          echo "changed=yes comment='loaded nct6775'"
        else
          echo "changed=no comment='nct6775 unavailable on this kernel; skipping'"
        fi
    - shell: /bin/bash
    - stateful: True

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
