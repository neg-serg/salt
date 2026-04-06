{% from '_imports.jinja' import host %}
{% from '_macros_config.jinja' import config_file_edit %}
# Kernel boot parameters for CachyOS (Limine bootloader).
#
# Applied by editing kernel_cmdline in limine.conf. Requires reboot.
# Run: sudo salt-call --local -c .salt_runtime state.sls kernel_params_limine

{% import_yaml 'data/kernel_params.yaml' as kp %}

{# Assemble kargs from data file + host-specific conditionals #}
{% set kargs = kp.common[:] %}
{% if host.cpu_vendor == 'amd' %}
{% do kargs.extend(kp.amd) %}
{% elif host.cpu_vendor == 'intel' %}
{% do kargs.extend(kp.intel) %}
{% endif %}
{% if host.display %}
{% do kargs.append('video=' ~ host.display) %}
{% endif %}
{% if not host.is_laptop %}
{% do kargs.extend(kp.desktop) %}
{% endif %}
{% if host.is_laptop %}
{% do kargs.extend(kp.laptop) %}
{% endif %}
{% for karg in host.extra_kargs %}
{% do kargs.append(karg) %}
{% endfor %}
