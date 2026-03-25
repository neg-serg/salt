{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import config_replace_with_service_control, ensure_dir, service_stopped, service_with_healthcheck, service_with_unit, unit_override %}
{% from '_macros_pkg.jinja' import pacman_install, simple_service %}
{% import_yaml 'data/services.yaml' as services %}
{% import_yaml 'data/service_catalog.yaml' as catalog %}
{% set svc = host.features.services %}
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

{% if svc.get('transmission', False) %}
{{ service_with_healthcheck('transmission_start', 'transmission', catalog=catalog, requires=['service: transmission_enabled']) }}
{% endif %}

# ===================================================================
# Complex services (custom logic, not data-driven)
# ===================================================================

# --- Samba: SMB file sharing (manual start) ---
{% if svc.samba %}
{{ pacman_install('samba', 'samba') }}

{{ ensure_dir('samba_share_dir', host.mnt_zero ~ '/sync/smb', mode='0755', require=['mount: mount_zero']) }}

samba_config:
  file.managed:
    - name: /etc/samba/smb.conf
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/smb.conf.j2
    - template: jinja
    - context:
        hostname: {{ host.hostname }}
        mnt_zero: {{ host.mnt_zero }}
        user: {{ user }}
    - require:
      - cmd: install_samba

# Don't enable at boot — manual start only: systemctl start smb
{{ service_stopped('samba_not_enabled', 'smb', stop=False, requires=['file: samba_config']) }}
{% endif %}

# --- DuckDNS: dynamic DNS updater ---
{% if svc.duckdns %}
duckdns_script:
  file.managed:
    - name: /usr/local/bin/duckdns-update
    - mode: '0755'
    - source: salt://scripts/duckdns-update.sh

# Timer disabled by default — enable after creating /etc/duckdns.env
{{ service_with_unit('duckdns-update', 'salt://units/duckdns-update.timer', unit_type='timer', enabled=False, companion='salt://units/duckdns-update.service') }}
{% endif %}

# --- Transmission: directories, ACLs, settings ---
{% if svc.transmission %}
{% set transmission_cfg = '/var/lib/transmission/.config/transmission-daemon/settings.json' %}
{% set transmission_watch_dir = home ~ '/dw' %}
{% set transmission_download_dir = home ~ '/torrent/data' %}

{{ ensure_dir('transmission_watch_dir', transmission_watch_dir) }}
{{ ensure_dir('transmission_download_dir', transmission_download_dir) }}

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
        getfacl -p {{ home }} | rg -q '^user:transmission:r-x$' &&
        getfacl -p {{ transmission_watch_dir }} | rg -q '^user:transmission:rwx$' &&
        getfacl -d {{ transmission_watch_dir }} | rg -q '^user:transmission:rwx$' &&
        getfacl -p {{ transmission_download_dir }} | rg -q '^user:transmission:rwx$' &&
        getfacl -d {{ transmission_download_dir }} | rg -q '^user:transmission:rwx$'
    - require:
      - cmd: install_transmission
      - file: transmission_watch_dir
      - file: transmission_download_dir

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

# ===================================================================
# Bitcoind: Bitcoin Core node (merged from services_bitcoind.sls)
# ===================================================================

{% if svc.bitcoind %}
{{ pacman_install('bitcoind', 'bitcoin-daemon') }}

# One-time cleanup: remove old manually-installed binaries
bitcoind_legacy_cleanup:
  file.absent:
    - names:
      - /usr/local/bin/bitcoind
      - /usr/local/bin/bitcoin-cli
    - onlyif: test -f /usr/local/bin/bitcoind

# Don't enable at boot — manual start: systemctl start bitcoind
{{ service_with_unit('bitcoind', 'salt://units/bitcoind.service', enabled=False, requires=['cmd: managed_service_accounts_ensure', 'cmd: managed_service_paths_ensure']) }}

bitcoind_logrotate:
  file.managed:
    - name: /etc/logrotate.d/bitcoind
    - mode: '0644'
    - source: salt://configs/bitcoind-logrotate
{% endif %}
