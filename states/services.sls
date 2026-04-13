{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import config_replace_with_service_control, ensure_dir, ensure_running, service_stopped, service_with_healthcheck, service_with_unit, unit_override %}
{% from '_macros_pkg.jinja' import pacman_install, simple_service, paru_install %}
{% import_yaml 'data/services.yaml' as services %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% set svc = host.features.services %}
{% set net = host.features.network %}
{% set dns = host.features.dns %}
{% set mon = host.features.monitoring %}

# ===================================================================
# Simple services (data-driven: pacman install + service enable)
# ===================================================================

{% for name, opts in services.simple.items() %}
{% if svc.get(name, False) %}
{{ simple_service(name, opts.packages, service=opts.service) }}
{% endif %}
{% endfor %}

# --- Health checks for network services ---
{% if svc.get('jellyfin', False) %}
{{ service_with_healthcheck('jellyfin_start', 'jellyfin', catalog=catalog, requires=['service: jellyfin_enabled']) }}
{% endif %}

# ===================================================================
# Complex services (data-driven from services.yaml complex: section)
# ===================================================================

{% set known_vars = {
    'hostname': host.hostname,
    'mnt_zero': host.mnt_zero,
    'mnt_one': host.mnt_one,
    'user': user,
    'home': home,
    'dns_unbound': dns.get('unbound', False),
} %}

{% set _valid_fields = ['packages', 'unit', 'manual_start', 'dirs', 'config_templates', 'scripts',
    'healthcheck', 'logrotate', 'cleanup', 'has_escape_hatch'] %}
{% for name, opts in services.get('complex', {}).items() %}
{# Schema validation: emit a fail state for invalid definitions #}
{% set _actionable = opts.keys() | reject('equalto', 'has_escape_hatch') | list %}
{% if not _actionable %}
validate_{{ name }}_no_fields:
  test.fail_without_changes:
    - name: 'complex service "{{ name }}" has no actionable fields — add at least one of: {{ _valid_fields | join(", ") }}'
{% endif %}
{% for field in opts.keys() %}
{% if field not in _valid_fields %}
validate_{{ name }}_unknown_{{ field }}:
  test.fail_without_changes:
    - name: 'complex service "{{ name }}" has unknown field "{{ field }}" — valid fields: {{ _valid_fields | join(", ") }}'
{% endif %}
{% endfor %}

{% if svc.get(name, False) %}

# --- {{ name }} (data-driven) ---

{# cleanup: one-time file removal #}
{% if opts.cleanup is defined %}
{{ name }}_cleanup:
  file.absent:
    - names:
{% for p in opts.cleanup.paths %}
      - {{ p }}
{% endfor %}
    - onlyif: {{ opts.cleanup.onlyif }}
{% endif %}

{# packages: pacman install #}
{% if opts.packages is defined %}
{{ pacman_install(name, opts.packages) }}
{% endif %}

{# dirs: create directories #}
{% if opts.dirs is defined %}
{% for d in opts.dirs %}
{{ ensure_dir(name ~ '_dir_' ~ loop.index0, d.path, mode=d.get('mode'), require=d.get('require')) }}
{% endfor %}
{% endif %}

{# scripts: deploy executable files #}
{% if opts.scripts is defined %}
{% for s in opts.scripts %}
{{ name }}_script_{{ loop.index0 }}:
  file.managed:
    - name: {{ s.dest }}
    - mode: '0755'
    - source: {{ s.source }}
{% endfor %}
{% endif %}

{# config_templates: deploy config files with context resolution #}
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
{% do _ct_requires.append('cmd: install_' ~ name) %}
{% endif %}
{% if ct.get('require') is defined %}
{% for r in ct.require %}
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
{% endfor %}
{% endif %}

{# unit: systemd unit management #}
{% if opts.unit is defined %}
{% set u = opts.unit %}
{% set unit_requires = [] %}
{% if opts.packages is defined %}
{% do unit_requires.append('cmd: install_' ~ name) %}
{% endif %}
{% if u.get('requires') is defined %}
{% for r in u.requires %}
{% do unit_requires.append(r) %}
{% endfor %}
{% endif %}
{{ service_with_unit(name, u.source, unit_type=u.get('type', 'service'), enabled=u.get('enabled', True), running=u.get('running', False), companion=u.get('companion'), template=u.get('template'), context=u.get('unit_context'), requires=unit_requires if unit_requires else None) }}
{% endif %}

{# manual_start: disable service at boot #}
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

{# logrotate: deploy logrotate config #}
{% if opts.logrotate is defined %}
{{ name }}_logrotate:
  file.managed:
    - name: /etc/logrotate.d/{{ name }}
    - mode: '0644'
    - source: {{ opts.logrotate.source }}
{% endif %}

{# healthcheck: poll health after service start #}
{% if opts.healthcheck is defined %}
{% set hc = opts.healthcheck %}
{{ service_with_healthcheck(name ~ '_start', name, hc.command, requires=hc.get('requires')) }}
{% endif %}

{# escape_hatch marker #}
{% if opts.get('has_escape_hatch', False) %}
# --- {{ name }}: escape hatch (inline logic below loop) ---
{% endif %}

{% endif %}
{% endfor %}

# ===================================================================
# Network services (data-driven from services.yaml network: section)
# ===================================================================

{% for name, opts in services.get('network', {}).items() %}
{% if net.get(name, False) %}

# --- {{ name }} (network, data-driven) ---

{# cleanup: one-time file removal #}
{% if opts.cleanup is defined %}
{{ name }}_cleanup:
  file.absent:
    - names:
{% for p in opts.cleanup.paths %}
      - {{ p }}
{% endfor %}
    - onlyif: {{ opts.cleanup.onlyif }}
{% endif %}

{# packages: pacman or paru install #}
{% if opts.packages is defined %}
{% if opts.get('package_manager') == 'paru' %}
{{ paru_install(name, opts.packages) }}
{% else %}
{{ pacman_install(name, opts.packages) }}
{% endif %}
{% endif %}

{# dirs: create directories #}
{% if opts.dirs is defined %}
{% for d in opts.dirs %}
{{ ensure_dir(name ~ '_dir_' ~ loop.index0, d.path, mode=d.get('mode'), require=d.get('require')) }}
{% endfor %}
{% endif %}

{# scripts: deploy executable files #}
{% if opts.scripts is defined %}
{% for s in opts.scripts %}
{{ name }}_script_{{ loop.index0 }}:
  file.managed:
    - name: {{ s.dest }}
    - mode: '0755'
    - source: {{ s.source }}
{% endfor %}
{% endif %}

{# config_templates: deploy config files #}
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
{% if opts.get('package_manager') == 'paru' %}
{% do _ct_requires.append('cmd: install_' ~ name | replace('-', '_')) %}
{% else %}
{% do _ct_requires.append('cmd: install_' ~ name) %}
{% endif %}
{% endif %}
{% if ct.get('require') is defined %}
{% for r in ct.require %}
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

{# unit: systemd unit management #}
{% if opts.unit is defined %}
{% set u = opts.unit %}
{% set unit_requires = [] %}
{% if opts.packages is defined %}
{% if opts.get('package_manager') == 'paru' %}
{% do unit_requires.append('cmd: install_' ~ name | replace('-', '_')) %}
{% else %}
{% do unit_requires.append('cmd: install_' ~ name) %}
{% endif %}
{% endif %}
{% if u.get('requires') is defined %}
{% for r in u.requires %}
{% do unit_requires.append(r) %}
{% endfor %}
{% endif %}
{{ service_with_unit(name, u.source, unit_type=u.get('type', 'service'), enabled=u.get('enabled', True), running=u.get('running', False), companion=u.get('companion'), template=u.get('template'), context=u.get('unit_context'), requires=unit_requires if unit_requires else None) }}
{% endif %}

{# simple service: packages + enable package-provided service (no custom unit) #}
{% if opts.service is defined and opts.unit is not defined %}
{% if opts.packages is defined %}
{{ simple_service(name, opts.packages, service=opts.service) }}
{% endif %}
{% endif %}

{# manual_start: disable service at boot #}
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

{# logrotate: deploy logrotate config #}
{% if opts.logrotate is defined %}
{{ name }}_logrotate:
  file.managed:
    - name: /etc/logrotate.d/{{ name }}
    - mode: '0644'
    - source: {{ opts.logrotate.source }}
{% endif %}

{# healthcheck: poll health after service start #}
{% if opts.healthcheck is defined %}
{% set hc = opts.healthcheck %}
{{ service_with_healthcheck(name ~ '_start', name, hc.command, requires=hc.get('requires')) }}
{% endif %}

{# escape_hatch marker #}
{% if opts.get('has_escape_hatch', False) %}
# --- {{ name }}: escape hatch (inline logic below loop) ---
{% endif %}

{% endif %}
{% endfor %}

# ===================================================================
# DNS services (data-driven from services.yaml dns: section)
# ===================================================================

{% for name, opts in services.get('dns', {}).items() %}
{% if dns.get(name, False) %}

# --- {{ name }} (dns, data-driven) ---

{# cleanup: one-time file removal #}
{% if opts.cleanup is defined %}
{{ name }}_cleanup:
  file.absent:
    - names:
{% for p in opts.cleanup.paths %}
      - {{ p }}
{% endfor %}
    - onlyif: {{ opts.cleanup.onlyif }}
{% endif %}

{# packages: pacman install (skip when simple_service will handle it) #}
{% if opts.packages is defined and not (opts.service is defined and opts.unit is not defined) %}
{{ pacman_install(name, opts.packages) }}
{% endif %}

{# dirs: create directories #}
{% if opts.dirs is defined %}
{% for d in opts.dirs %}
{{ ensure_dir(name ~ '_dir_' ~ loop.index0, d.path, mode=d.get('mode'), require=d.get('require')) }}
{% endfor %}
{% endif %}

{# config_templates: deploy config files with context resolution #}
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
{% do _ct_requires.append('cmd: install_' ~ name) %}
{% endif %}
{% if ct.get('require') is defined %}
{% for r in ct.require %}
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

{# setup_commands: initialization commands with creates/onlyif guards #}
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
      - cmd: install_{{ name }}
{% endif %}
{% endfor %}
{% endif %}

{# unit: systemd unit management #}
{% if opts.unit is defined %}
{% set u = opts.unit %}
{% set unit_requires = [] %}
{% if opts.packages is defined %}
{% do unit_requires.append('cmd: install_' ~ name) %}
{% endif %}
{% if u.get('requires') is defined %}
{% for r in u.requires %}
{% do unit_requires.append(r) %}
{% endfor %}
{% endif %}
{{ service_with_unit(name, u.source, unit_type=u.get('type', 'service'), enabled=u.get('enabled', True), running=u.get('running', False), companion=u.get('companion'), template=u.get('template'), context=u.get('unit_context'), requires=unit_requires if unit_requires else None) }}
{% endif %}

{# simple service: packages + enable package-provided service (no custom unit) #}
{% if opts.service is defined and opts.unit is not defined %}
{% if opts.packages is defined %}
{{ simple_service(name, opts.packages, service=opts.service) }}
{% endif %}
{% endif %}

{# unit_override: systemd drop-in override #}
{% if opts.unit_override is defined %}
{% set uo = opts.unit_override %}
{{ unit_override(uo.name, uo.service, uo.source, requires=['cmd: install_' ~ name]) }}
{% endif %}

{# ensure_running: reset_failed + service.running with watches #}
{% if opts.ensure_running is defined %}
{% set er = opts.ensure_running %}
{{ ensure_running(name ~ '_running', er.service, watch=er.get('watch')) }}
{% endif %}

{# healthcheck: poll health after service start #}
{% if opts.healthcheck is defined %}
{% set hc = opts.healthcheck %}
{{ service_with_healthcheck(name ~ '_start', name, hc.command, requires=hc.get('requires')) }}
{% endif %}

{% endif %}
{% endfor %}

# ===================================================================
# Escape hatches + remaining inline services
# ===================================================================

# --- Transmission: escape hatch (ACLs, settings, stop/restart lifecycle) ---
# Dirs and healthcheck handled by complex.transmission in the orchestrator loop.
{% if svc.transmission %}
{% set transmission_cfg = '/var/lib/transmission/.config/transmission-daemon/settings.json' %}
{% set transmission_watch_dir = home ~ '/dw' %}
{% set transmission_download_dir = home ~ '/torrent/data' %}

transmission_acl_setup:
  cmd.run:
    - name: |
        set -e
        setfacl -m u:transmission:rx {{ home }}
        setfacl -m u:transmission:rx {{ home }}/torrent
        setfacl -m u:transmission:rwX {{ transmission_watch_dir }}
        setfacl -d -m u:transmission:rwX {{ transmission_watch_dir }}
        setfacl -m u:transmission:rwX {{ transmission_download_dir }}
        setfacl -d -m u:transmission:rwX {{ transmission_download_dir }}
    - shell: /bin/bash
    - unless: |
        getfacl -p {{ home }} | grep -q '^user:transmission:r-x$' &&
        getfacl -p {{ home }}/torrent | grep -q '^user:transmission:r-x$' &&
        getfacl -p {{ transmission_watch_dir }} | grep -q '^user:transmission:rwx$' &&
        getfacl -d {{ transmission_watch_dir }} | grep -q '^user:transmission:rwx$' &&
        getfacl -p {{ transmission_download_dir }} | grep -q '^user:transmission:rwx$' &&
        getfacl -d {{ transmission_download_dir }} | grep -q '^user:transmission:rwx$'
    - require:
      - cmd: install_transmission
      - file: transmission_dir_0
      - file: transmission_dir_1

{% set transmission_settings_replacements = [
  ('transmission_download_dir_setting', '^\\s*"download-dir"\\s*:\\s*".*"(?P<suffix>,?)', '    "download-dir": "' ~ transmission_download_dir ~ '"\\g<suffix>'),
  ('transmission_watch_dir_setting', '^\\s*"watch-dir"\\s*:\\s*".*"(?P<suffix>,?)', '    "watch-dir": "' ~ transmission_watch_dir ~ '"\\g<suffix>'),
  ('transmission_watch_dir_enabled', '^\\s*"watch-dir-enabled"\\s*:\\s*(true|false)(?P<suffix>,?)', '    "watch-dir-enabled": true\\g<suffix>'),
] %}

{{ config_replace_with_service_control(
  'transmission_settings',
  transmission_cfg,
  'transmission',
  transmission_settings_replacements,
  requires=['cmd: install_transmission', 'cmd: transmission_acl_setup'],
  service_require=['service: transmission_enabled', 'cmd: transmission_start']
) }}
{% endif %}

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

