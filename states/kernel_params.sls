# Kernel boot parameters migrated from NixOS (modules/system/kernel/params.nix,
# hosts/telfir/hardware.nix, modules/system/profiles/)
#
# Applied via rpm-ostree kargs. Requires reboot to take effect.

{% set kargs = [
    'amd_pstate=active',
    '8250.nr_uarts=0',
    'video=3840x2160@240',
    'nvme_core.default_ps_max_latency_us=0',
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
] %}

{% for karg in kargs %}
karg_{{ karg.split('=')[0] | replace('.', '_') }}:
  cmd.run:
    - name: rpm-ostree kargs --append={{ karg }}
    - unless: rpm-ostree kargs | grep -q '{{ karg }}'
{% endfor %}
