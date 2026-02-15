# Centralized build cache on external storage (/mnt/one/pkg/cache)
# Subdirectories: rpms/ (custom RPM builds), amnezia/ (Amnezia VPN builds)
# Requires mount_one from system_description.sls

{% set cache_dir = '/mnt/one/pkg/cache' %}

{{ cache_dir }}:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True
    - require:
      - mount: mount_one

{{ cache_dir }}/rpms:
  file.directory:
    - user: neg
    - group: neg
    - require:
      - file: {{ cache_dir }}

{{ cache_dir }}/amnezia:
  file.directory:
    - user: neg
    - group: neg
    - require:
      - file: {{ cache_dir }}

# SELinux: rpm_var_cache_t for rpms/ so rpm-ostree (rpm_t) can read without AVC denials
# Uses /mnt equivalency (not /mnt) per Fedora Atomic semanage convention
{% from '_macros.jinja' import selinux_fcontext %}
{{ selinux_fcontext('pkg_cache_selinux', '/mnt/one/pkg/cache/rpms', '/mnt/one/pkg/cache', 'rpm_var_cache_t', check_path='/mnt/one/pkg/cache/rpms', requires=['file: ' ~ cache_dir ~ '/rpms']) }}
