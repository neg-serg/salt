# Centralized build cache on external storage (/var/mnt/one/pkg/cache)
# Subdirectories: rpms/ (custom RPM builds), amnezia/ (Amnezia VPN builds)
# Requires mount_one from system_description.sls

{% set cache_dir = '/var/mnt/one/pkg/cache' %}

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

# One-time migration from old paths (cross-filesystem cp -a, then remove old dir)
migrate_rpms_cache:
  cmd.run:
    - name: |
        cp -a /var/home/neg/src/salt/rpms/. {{ cache_dir }}/rpms/ &&
        rm -rf /var/home/neg/src/salt/rpms
    - onlyif: test -d /var/home/neg/src/salt/rpms && ls /var/home/neg/src/salt/rpms/*.rpm >/dev/null 2>&1
    - require:
      - file: {{ cache_dir }}/rpms

migrate_amnezia_cache:
  cmd.run:
    - name: |
        cp -a /var/home/neg/src/amnezia_build/. {{ cache_dir }}/amnezia/ &&
        rm -rf /var/home/neg/src/amnezia_build
    - onlyif: test -d /var/home/neg/src/amnezia_build && test -f /var/home/neg/src/amnezia_build/amneziawg-go-bin
    - require:
      - file: {{ cache_dir }}/amnezia

# SELinux: rpm_var_cache_t for rpms/ so rpm-ostree (rpm_t) can read without AVC denials
# Uses /mnt equivalency (not /var/mnt) per Fedora Atomic semanage convention
pkg_cache_selinux:
  cmd.run:
    - name: |
        semanage fcontext -a -t rpm_var_cache_t "/mnt/one/pkg/cache/rpms(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t rpm_var_cache_t "/mnt/one/pkg/cache/rpms(/.*)?"
        restorecon -Rv /var/mnt/one/pkg/cache
    - unless: ls -Zd /var/mnt/one/pkg/cache/rpms 2>/dev/null | grep -q rpm_var_cache_t
    - require:
      - file: {{ cache_dir }}/rpms
      - cmd: migrate_rpms_cache
