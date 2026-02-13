{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload %}

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
    - contents: |
        #!/usr/bin/env bash
        set -eu
        case "${1:-}" in
          post)
            # Re-enable manual PWM control for motherboard fans (nct6775)
            for d in /sys/class/hwmon/hwmon*; do
              if [ -f "$d/name" ] && grep -Eiq '^nct' "$d/name"; then
                for en in "$d"/pwm[1-9]_enable; do
                  [ -e "$en" ] || continue
                  echo 1 > "$en" 2>/dev/null || true
                done
              fi
            done
            # Re-enable AMDGPU pwm1 manual control
            {% if host.get('cpu_vendor', '') == 'amd' %}
            for d in /sys/class/hwmon/hwmon*; do
              if [ -f "$d/name" ] && grep -Eiq '^amdgpu$' "$d/name"; then
                [ -w "$d/pwm1_enable" ] && echo 1 > "$d/pwm1_enable" 2>/dev/null || true
              fi
            done
            {% endif %}
            # Restart fancontrol to pick up refreshed hwmon state
            systemctl try-restart fancontrol.service >/dev/null 2>&1 || true
            ;;
        esac

fancontrol_setup_service:
  file.managed:
    - name: /etc/systemd/system/fancontrol-setup.service
    - source: salt://units/fancontrol-setup.service.j2
    - template: jinja
    - context:
        gpu_enable: {{ 'true' if host.get('cpu_vendor', '') == 'amd' else 'false' }}
    - mode: '0644'

fancontrol_service:
  file.managed:
    - name: /etc/systemd/system/fancontrol.service
    - source: salt://units/fancontrol.service
    - mode: '0644'

{{ daemon_reload('fancontrol', ['file: fancontrol_setup_service', 'file: fancontrol_service']) }}

fancontrol_enable:
  service.enabled:
    - name: fancontrol
    - require:
      - file: fancontrol_service
      - file: fancontrol_setup_service
      - file: fancontrol_setup_script

# Load nct6775 kernel module for motherboard PWM fan control
nct6775_module:
  kmod.present:
    - name: nct6775

{% endif %}
