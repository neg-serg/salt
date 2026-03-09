# Simple monitoring services: sysstat, vnstat, netdata
{% from '_imports.jinja' import host %}
{% from '_macros_service.jinja' import unit_override %}
{% from '_macros_pkg.jinja' import simple_service %}
{% set mon = host.features.monitoring %}

# --- Simple service enables ---
{% if mon.sysstat %}
{{ simple_service('sysstat', 'sysstat') }}
{% endif %}

{% if mon.vnstat %}
{{ simple_service('vnstat', 'vnstat') }}
{% endif %}

# --- Netdata: systemd override for conservative resource limits ---
{% if mon.netdata %}
{{ unit_override('netdata_override', 'netdata.service', 'salt://units/netdata-override.conf') }}
{% endif %}
