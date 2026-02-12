{% from 'host_config.jinja' import host %}
# Kernel boot parameters migrated from NixOS (modules/system/kernel/params.nix,
# hosts/telfir/hardware.nix, modules/system/profiles/)
#
# Applied via rpm-ostree kargs. Requires reboot to take effect.
#
# Hardware / display:   cpu pstate, 8250, video, nvme_core, acpi_osi
# Memory:               lru_gen, transparent_hugepage, mem_sleep_default
# Security hardening:   page_alloc, slab_nomerge, init_on_alloc, kstack, vsyscall, debugfs
# Performance profile:  noreplace-smp, pcie_aspm, rcu, tsc, split_lock, watchdog, idle, usb

{# Common kernel parameters (all hosts) #}
{% set kargs = [
    '8250.nr_uarts=0',
    'nvme_core.default_ps_max_latency_us=0',
    'lru_gen=1',
    'lru_gen.min_ttl_ms=1000',
    'transparent_hugepage=madvise',
    'page_alloc.shuffle=1',
    'slab_nomerge',
    'init_on_alloc=1',
    'randomize_kstack_offset=on',
    'vsyscall=none',
    'debugfs=off',
    'vt.global_cursor_default=0',
    'noreplace-smp',
    'pcie_aspm=performance',
    'rcupdate.rcu_expedited=1',
    'tsc=reliable',
    'split_lock_detect=off',
    'nowatchdog',
    'kernel.nmi_watchdog=0',
    'idle=nomwait',
    'usbcore.autosuspend=-1',
] %}

{# CPU-vendor-specific P-state driver #}
{% if host.cpu_vendor == 'amd' %}
{% do kargs.append('amd_pstate=active') %}
{% elif host.cpu_vendor == 'intel' %}
{% do kargs.append('intel_pstate=active') %}
{% endif %}

{# Display resolution (host-specific) #}
{% if host.display %}
{% do kargs.append('video=' ~ host.display) %}
{% endif %}

{# ACPI compatibility (desktop BIOS quirk) #}
{% if not host.is_laptop %}
{% do kargs.extend(['acpi_osi=!', 'acpi_osi=Linux']) %}
{% endif %}

{# Suspend-to-RAM (laptop-only) #}
{% if host.is_laptop %}
{% do kargs.append('mem_sleep_default=deep') %}
{% endif %}

{# Per-host extra kargs #}
{% for karg in host.extra_kargs %}
{% do kargs.append(karg) %}
{% endfor %}

set_kernel_params:
  cmd.run:
    - name: |
        current=$(rpm-ostree kargs)
        wanted=({% for karg in kargs %}'{{ karg }}' {% endfor %})
        missing=()
        for k in "${wanted[@]}"; do
          [[ "$current" == *"$k"* ]] || missing+=("$k")
        done
        if [ -n "${missing[*]}" ]; then
          args=()
          for k in "${missing[@]}"; do args+=("--append=$k"); done
          rpm-ostree kargs "${args[@]}"
        fi
    - unless: |
        current=$(rpm-ostree kargs)
        wanted=({% for karg in kargs %}'{{ karg }}' {% endfor %})
        for k in "${wanted[@]}"; do
          [[ "$current" == *"$k"* ]] || exit 1
        done
