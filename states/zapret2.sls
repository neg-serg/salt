{% from '_imports.jinja' import user %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit %}
{% import_yaml 'data/zapret2.yaml' as zapret2 %}

{% set cfg_dir = zapret2.config.dir %}
{% set cfg_path = zapret2.config.path %}
{% set hostlist_dir = zapret2.hostlist.dir %}
{% set hostlist_path = zapret2.hostlist.path %}
{% set helper_path = zapret2.helper.deployed_path %}
{% set approval_file = zapret2.helper.approval_file %}

zapret2_install_pkg:
  cmd.run:
    - name: sudo -u {{ user }} paru -S --noconfirm --needed {{ zapret2.package.name }}
    - unless: pacman -Q {{ zapret2.package.name }}

zapret2_install_ipset:
  cmd.run:
    - name: pacman -S --noconfirm --needed ipset
    - unless: pacman -Q ipset

{{ ensure_dir('zapret2_config_dir', cfg_dir, mode='0755', user='root') }}
{{ ensure_dir('zapret2_hostlist_dir', hostlist_dir, mode='0755', user='root') }}
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
        ws_user: {{ zapret2.config.ws_user }}
        fwtype: {{ zapret2.config.fwtype }}
        getlist: {{ zapret2.config.getlist }}
        mode_filter: {{ zapret2.config.mode_filter }}
        disable_ipv6: {{ zapret2.config.disable_ipv6 }}
        helper_path: {{ helper_path }}
        approval_file: {{ approval_file }}
        tcp_ports: {{ zapret2.config.tcp_ports }}
        udp_ports: {{ zapret2.config.udp_ports }}
        quic_kyber_blobs: {{ zapret2.config.quic_kyber_blobs }}
        tls_google_blob: {{ zapret2.config.tls_google_blob }}
        vpn_domains: {{ zapret2.vpn_providers.domains | join(',') }}
    - require:
      - file: zapret2_config_dir

zapret2_hostlist:
  file.managed:
    - name: {{ hostlist_path }}
    - mode: '0644'
    - source: salt://configs/zapret2-hosts-user.txt.j2
    - template: jinja
    - context:
        domains: {{ zapret2.hostlist.domains }}
    - require:
      - file: zapret2_hostlist_dir

zapret2_refresh_lists:
  cmd.run:
    - name: /opt/zapret2/ipset/get_config.sh
    - onchanges:
      - file: zapret2_config
      - file: zapret2_hostlist
    - require:
      - cmd: zapret2_install_pkg
      - cmd: zapret2_install_ipset

zapret2_list_update_timer:
  service.running:
    - name: zapret2-list-update.timer
    - enable: True
    - require:
      - cmd: zapret2_install_pkg
      - cmd: zapret2_install_ipset
      - cmd: zapret2_refresh_lists

{{ service_with_unit(
  'zapret2',
  'salt://units/zapret2.service.j2',
  enabled=True,
  running=True,
  template='jinja',
  context={
    'config_path': cfg_path,
    'helper_path': helper_path,
    'approval_file': approval_file,
  },
  requires=['cmd: zapret2_install_pkg', 'cmd: zapret2_install_ipset', 'file: zapret2_config', 'file: zapret2_hostlist', 'file: zapret2_helper_script', 'cmd: zapret2_refresh_lists', 'service: zapret2_list_update_timer']
) }}
