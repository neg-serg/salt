{% import_yaml 'data/managed_resources.yaml' as managed %}
{% from '_macros_service.jinja' import managed_identity_guard, managed_path_guard %}

{% set identities = managed.get('managed_service_identities', {}) %}
{% set paths = managed.get('managed_service_paths', {}) %}

managed_service_accounts_dir:
  file.directory:
    - name: /etc/sysusers.d
    - user: root
    - group: root
    - mode: '0755'

managed_service_accounts_conf:
  file.managed:
    - name: /etc/sysusers.d/salt-managed-service-accounts.conf
    - source: salt://configs/managed-service-accounts.conf.j2
    - template: jinja
    - mode: '0644'
    - context:
        identities: {{ identities }}
    - require:
      - file: managed_service_accounts_dir

managed_service_accounts_apply:
  cmd.run:
    - name: systemd-sysusers /etc/sysusers.d/salt-managed-service-accounts.conf
    - onchanges:
      - file: managed_service_accounts_conf
    - require:
      - file: managed_service_accounts_conf

managed_service_accounts_ensure:
  cmd.run:
    - name: systemd-sysusers /etc/sysusers.d/salt-managed-service-accounts.conf
{% if identities %}
    - unless: |
{%- for _name, _entry in identities|dictsort %}
        {{ managed_identity_guard(_entry) }}{% if not loop.last %} &&{% endif %}
{%- endfor %}
{% else %}
    - unless: test 1 = 1
{% endif %}
    - require:
      - file: managed_service_accounts_conf

managed_service_paths_dir:
  file.directory:
    - name: /etc/tmpfiles.d
    - user: root
    - group: root
    - mode: '0755'

managed_service_paths_conf:
  file.managed:
    - name: /etc/tmpfiles.d/salt-managed-service-paths.conf
    - source: salt://configs/managed-service-paths.conf.j2
    - template: jinja
    - mode: '0644'
    - context:
        paths: {{ paths }}
    - require:
      - file: managed_service_paths_dir

managed_service_paths_apply:
  cmd.run:
    - name: systemd-tmpfiles --create /etc/tmpfiles.d/salt-managed-service-paths.conf
    - onchanges:
      - file: managed_service_paths_conf
    - require:
      - file: managed_service_paths_conf

managed_service_paths_ensure:
  cmd.run:
    - name: systemd-tmpfiles --create /etc/tmpfiles.d/salt-managed-service-paths.conf
{% if paths %}
    - unless: |
{%- for _name, _entry in paths|dictsort %}
        {{ managed_path_guard(_entry) }}{% if not loop.last %} &&{% endif %}
{%- endfor %}
{% else %}
    - unless: test 1 = 1
{% endif %}
    - require:
      - file: managed_service_paths_conf
