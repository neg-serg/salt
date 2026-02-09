# Kernel boot parameters migrated from NixOS (modules/system/kernel/params.nix,
# hosts/telfir/hardware.nix, modules/system/profiles/)
#
# Applied via rpm-ostree kargs. Requires reboot to take effect.
#
# Hardware / display:   amd_pstate, 8250, video, nvme_core, acpi_osi
# Memory:               lru_gen, transparent_hugepage, mem_sleep_default
# Security hardening:   page_alloc, slab_nomerge, init_on_alloc, kstack, vsyscall, debugfs
# Performance profile:  noreplace-smp, pcie_aspm, rcu, tsc, split_lock, watchdog, idle, usb

{% set kargs = [
    'amd_pstate=active',
    '8250.nr_uarts=0',
    'video=3840x2160@240',
    'nvme_core.default_ps_max_latency_us=0',
    'acpi_osi=!',
    'acpi_osi=Linux',
    'lru_gen=1',
    'lru_gen.min_ttl_ms=1000',
    'transparent_hugepage=madvise',
    'mem_sleep_default=deep',
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

{% for karg in kargs %}
karg_{{ karg | replace('=', '_') | replace('.', '_') | replace('-', '_') | replace('!', 'not') }}:
  cmd.run:
    - name: rpm-ostree kargs --append='{{ karg }}'
    - unless: rpm-ostree kargs | grep -qF '{{ karg }}'
{% endfor %}
