{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import ensure_dir, ensure_running, service_stopped, service_with_healthcheck, service_with_unit, unit_override %}
{% from '_macros_pkg.jinja' import paru_install, simple_service %}
{% import_yaml 'data/services.yaml' as services %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% set svc = host.features.services %}
{% set net = host.features.network %}
{% set dns = host.features.dns %}
{% set mon = host.features.monitoring %}

# ===================================================================
# Simple services (data-driven: paru install + service enable)
# ===================================================================

{% for name, opts in services.simple.items() %}
{% if svc.get(name, False) %}
{{ simple_service(name, opts.packages, service=opts.service) }}
{% endif %}
{% endfor %}

# ===================================================================
# Orchestrated services (complex, network, dns — shared template)
# ===================================================================

{% set known_vars = {
    'hostname': host.hostname,
    'mnt_zero': host.mnt_zero,
    'mnt_one': host.mnt_one,
    'user': user,
    'home': home,
    'dns_unbound': dns.get('unbound', False),
} %}

{# Renders one service section from services.yaml data.
   Variables expected in scope: name, opts, feature_flag, section_label. #}
{% macro render_service(name, opts, feature_flag, section_label) %}
{% if feature_flag %}

# --- {{ name }} ({{ section_label }}, data-driven) ---

{# cleanup #}
{% if opts.cleanup is defined %}
{{ name }}_cleanup:
  file.absent:
    - names:
{% for p in opts.cleanup.paths %}
      - {{ p }}
{% endfor %}
    - onlyif: {{ opts.cleanup.onlyif }}
{% endif %}

{# packages (skip when simple_service will handle it) #}
{% if opts.packages is defined and not (opts.service is defined and opts.unit is not defined) %}
{{ paru_install(name, opts.packages) }}
{% endif %}

{# dirs #}
{% if opts.dirs is defined %}
{% for d in opts.dirs %}
{{ ensure_dir(name ~ '_dir_' ~ loop.index0, d.path, mode=d.get('mode'), require=d.get('require')) }}
{% endfor %}
{% endif %}

{# scripts #}
{% if opts.scripts is defined %}
{% for s in opts.scripts %}
{{ name }}_script_{{ loop.index0 }}:
  file.managed:
    - name: {{ s.dest }}
    - mode: '0755'
    - source: {{ s.source }}
{% endfor %}
{% endif %}

{# config_templates #}
{% if opts.config_templates is defined %}
{% for ct in opts.config_templates %}
{% set resolved_ctx = {} %}
{% for k, v in ct.get('context', {}).items() %}
{% if v in known_vars %}
{% do resolved_ctx.update({k: known_vars[v]}) %}
{% else %}
{% do resolved_ctx.update({k: v}) %}
{% endif %}
{% endfor %}
{% set _ct_requires = [] %}
{% if opts.packages is defined %}
{% do _ct_requires.append('cmd: install_' ~ name | replace('-', '_')) %}
{% endif %}
{% if ct.get('require') %}
{% for r in ct.get('require') %}
{% do _ct_requires.append(r) %}
{% endfor %}
{% endif %}
{{ name }}_config_{{ loop.index0 }}:
  file.managed:
    - name: {{ ct.dest }}
    - source: {{ ct.source }}
    - mode: '{{ ct.get('mode', '0644') }}'
{% if ct.get('makedirs', False) %}
    - makedirs: True
{% endif %}
{% if ct.get('template', 'jinja') %}
    - template: {{ ct.get('template', 'jinja') }}
{% endif %}
{% if ct.get('replace', True) == false %}
    - replace: False
{% endif %}
{% if ct.get('user') %}
    - user: {{ ct.user }}
{% endif %}
{% if ct.get('group') %}
    - group: {{ ct.group }}
{% endif %}
{% if resolved_ctx %}
    - context:
{% for k, v in resolved_ctx.items() %}
        {{ k }}: {{ v }}
{% endfor %}
{% endif %}
{% if _ct_requires %}
    - require:
{% for r in _ct_requires %}
      - {{ r }}
{% endfor %}
{% endif %}
{% if ct.get('onchanges_restart') %}
    - onchanges:
      - cmd: {{ ct.onchanges_restart }}_restart_or_reload
{% endif %}
{% endfor %}
{% endif %}

{# setup_commands (dns only) #}
{% if opts.setup_commands is defined %}
{% for sc in opts.setup_commands %}
{{ name }}_setup_{{ loop.index0 }}:
  cmd.run:
    - name: {{ sc.name }}
{% if sc.get('creates') %}
    - creates: {{ sc.creates }}
{% endif %}
{% if sc.get('onlyif') %}
    - onlyif: {{ sc.onlyif }}
{% endif %}
{% if opts.packages is defined %}
    - require:
      - cmd: install_{{ name | replace('-', '_') }}
{% endif %}
{% endfor %}
{% endif %}

{# unit #}
{% if opts.unit is defined %}
{% set u = opts.unit %}
{% set unit_requires = [] %}
{% if opts.packages is defined %}
{% do unit_requires.append('cmd: install_' ~ name | replace('-', '_')) %}
{% endif %}
{% if u.get('requires') is defined %}
{% for r in u.requires %}
{% do unit_requires.append(r) %}
{% endfor %}
{% endif %}
{{ service_with_unit(name, u.source, unit_type=u.get('type', 'service'), enabled=u.get('enabled', True), running=u.get('running', False), companion=u.get('companion'), template=u.get('template'), context=u.get('unit_context'), requires=unit_requires if unit_requires else None) }}
{% endif %}

{# simple_service fallback (no custom unit) #}
{% if opts.service is defined and opts.unit is not defined %}
{% if opts.packages is defined %}
{{ simple_service(name, opts.packages, service=opts.service) }}
{% endif %}
{% endif %}

{# manual_start #}
{% if opts.manual_start is defined %}
{% set ms = opts.manual_start %}
{% set ms_requires = [] %}
{% if opts.config_templates is defined %}
{% for ct in opts.config_templates %}
{% do ms_requires.append('file: ' ~ name ~ '_config_' ~ loop.index0) %}
{% endfor %}
{% endif %}
{{ service_stopped(name ~ '_not_enabled', ms.service, stop=ms.get('stop', False), requires=ms_requires if ms_requires else None) }}
{% endif %}

{# unit_override (dns only) #}
{% if opts.unit_override is defined %}
{% set uo = opts.unit_override %}
{{ unit_override(uo.name, uo.service, uo.source, requires=['cmd: install_' ~ name | replace('-', '_')]) }}
{% endif %}

{# ensure_running (dns only) #}
{% if opts.ensure_running is defined %}
{% set er = opts.ensure_running %}
{{ ensure_running(name, er.service, watch=er.get('watch')) }}
{% endif %}

{# logrotate #}
{% if opts.logrotate is defined %}
{{ name }}_logrotate:
  file.managed:
    - name: /etc/logrotate.d/{{ name }}
    - mode: '0644'
    - source: {{ opts.logrotate.source }}
{% endif %}

{# healthcheck #}
{% if opts.healthcheck is defined %}
{% set hc = opts.healthcheck %}
{{ service_with_healthcheck(name ~ '_start', name, hc.command, requires=hc.get('requires')) }}
{% endif %}

{# escape_hatch marker #}
{% if opts.get('has_escape_hatch', False) %}
# --- {{ name }}: escape hatch (inline logic below loop) ---
{% endif %}

{% endif %}
{% endmacro %}

{# ── Complex services ── #}
{% for name, opts in services.get('complex', {}).items() %}
{{ render_service(name, opts, svc.get(name, False), 'complex') }}
{% endfor %}

{# ── Network services ── #}
{% for name, opts in services.get('network', {}).items() %}
{{ render_service(name, opts, net.get(name, False), 'network') }}
{% endfor %}

{# ── DNS services ── #}
{% for name, opts in services.get('dns', {}).items() %}
{{ render_service(name, opts, dns.get(name, False), 'dns') }}
{% endfor %}

# ===================================================================
# Monitoring services (merged from monitoring.sls)
# ===================================================================

{% if mon.sysstat %}
{{ simple_service('sysstat', 'sysstat') }}
{% endif %}

{% if mon.vnstat %}
{{ simple_service('vnstat', 'vnstat') }}
{% endif %}

{% if mon.netdata %}
{{ unit_override('netdata_override', 'netdata.service', 'salt://units/netdata-override.conf') }}
{% endif %}
