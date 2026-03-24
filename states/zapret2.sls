{% from '_macros_pkg.jinja' import paru_install %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit %}
{% import_yaml 'data/zapret2.yaml' as zapret2 %}

{% set cfg_dir = zapret2.config.dir %}
{% set cfg_path = zapret2.config.path %}
{% set helper_path = zapret2.helper.deployed_path %}
{% set approval_file = zapret2.helper.approval_file %}
{% set rollback_file = zapret2.helper.rollback_file %}

{{ paru_install('zapret2', zapret2.package.name) }}

{{ ensure_dir('zapret2_config_dir', cfg_dir, mode='0755', user='root') }}
{{ ensure_dir('zapret2_state_dir', '/var/lib/zapret2', mode='0755', user='root') }}
{{ ensure_dir('zapret2_helper_dir', '/usr/local/libexec', mode='0755', user='root') }}

zapret2_helper_script:
  file.managed:
    - name: {{ helper_path }}
    - mode: '0755'
    - source: salt://scripts/zapret2-rollout.sh
    - require:
      - file: zapret2_helper_dir

zapret2_config:
  file.managed:
    - name: {{ cfg_path }}
    - mode: '0644'
    - source: salt://configs/zapret2.conf.j2
    - template: jinja
    - context:
        package_source: {{ zapret2.package.source }}
        package_name: {{ zapret2.package.name }}
        default_mode: {{ zapret2.config.default_mode }}
        profile: {{ zapret2.config.profile }}
        helper_path: {{ helper_path }}
        approval_file: {{ approval_file }}
        rollback_file: {{ rollback_file }}
        tcp_ports: {{ zapret2.config.tcp_ports }}
        udp_ports: {{ zapret2.config.udp_ports }}
    - require:
      - file: zapret2_config_dir

{{ service_with_unit(
  'zapret2',
  'salt://units/zapret2.service.j2',
  enabled=False,
  template='jinja',
  context={
    'config_path': cfg_path,
    'helper_path': helper_path,
    'approval_file': approval_file,
    'rollback_file': rollback_file,
  },
  requires=['cmd: install_zapret2', 'file: zapret2_config', 'file: zapret2_helper_script']
) }}
