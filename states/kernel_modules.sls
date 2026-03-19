{% from '_imports.jinja' import host %}
# Kernel module loading and blacklisting migrated from NixOS
# (modules/system/kernel/params.nix, hosts/telfir/hardware.nix)
#
# modules-load.d: loaded at boot by systemd-modules-load.service
# modprobe.d: prevents module autoloading (security hardening)

kernel_modules_load:
  file.managed:
    - name: /etc/modules-load.d/custom.conf
    - contents: |
        # KVM virtualization ({{ host.cpu_vendor }})
        {{ host.kvm_module }}
        # BBR TCP congestion control
        tcp_bbr
        # NT synchronization primitives (Wine/Proton)
        ntsync
{% for mod in host.extra_modules %}
        # Host-specific: {{ mod }}
        {{ mod }}
{% endfor %}

kernel_modules_blacklist:
  file.managed:
    - name: /etc/modprobe.d/blacklist-custom.conf
    - source: salt://configs/modprobe-blacklist.conf.j2
    - template: jinja
    - context:
        cpu_vendor: {{ host.cpu_vendor }}

# Load modules now (no reboot needed); ignore missing-device errors
# (systemd-modules-load handles boot-time loading and is equally forgiving)
{% set modules_to_load = [host.kvm_module, 'tcp_bbr', 'ntsync'] + host.extra_modules %}
{% for mod in modules_to_load %}
load_{{ mod | replace('-', '_') }}:
  cmd.run:
    - name: modprobe {{ mod }} 2>/dev/null || true
    - unless: lsmod | rg -q '^{{ mod }}\b'
    - require:
      - file: kernel_modules_load
{% endfor %}
