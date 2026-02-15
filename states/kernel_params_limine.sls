{% from 'host_config.jinja' import host %}
# Kernel boot parameters for CachyOS (Limine bootloader).
# Manages kernel_cmdline entries in /boot/limine.conf.
#
# Applied by editing kernel_cmdline in limine.conf. Requires reboot.
# Run: sudo salt-call --local -c .salt_runtime state.sls kernel_params_limine

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

# Append missing kernel params to all kernel_cmdline entries in limine.conf.
# Preserves existing root= and other boot-critical params.
set_kernel_params_limine:
  cmd.run:
    - name: |
        LIMINE="/boot/limine.conf"
        WANTED=({% for karg in kargs %}'{{ karg }}' {% endfor %})

        # Build space-separated string of params not already present
        current=$(grep 'kernel_cmdline:' "$LIMINE" | head -1)
        missing=""
        for k in "${WANTED[@]}"; do
          # Match param key (before =) to avoid partial matches
          key="${k%%=*}"
          if ! grep -q "$key" <<< "$current"; then
            missing="$missing $k"
          fi
        done

        if [ -z "$missing" ]; then
          echo "All kernel params already present"
          exit 0
        fi

        echo "Adding kernel params:$missing"
        # Append to every kernel_cmdline line (primary + fallback entries)
        sed -i "s|^\(    kernel_cmdline:.*\)|\1$missing|" "$LIMINE"
    - unless: |
        LIMINE="/boot/limine.conf"
        WANTED=({% for karg in kargs %}'{{ karg }}' {% endfor %})
        current=$(grep 'kernel_cmdline:' "$LIMINE" | head -1)
        for k in "${WANTED[@]}"; do
          key="${k%%=*}"
          grep -q "$key" <<< "$current" || exit 1
        done
