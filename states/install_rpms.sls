# Salt state for custom RPM installation
# Installs all custom-built RPMs in a single rpm-ostree transaction
# Logic lives in build/rpm-install-helper.sh (check/install modes)

rpm_install_helper:
  file.managed:
    - name: /usr/local/bin/rpm-install-helper
    - source: salt://build/rpm-install-helper.sh
    - mode: '0755'

install_custom_rpms:
  cmd.run:
    - name: /usr/local/bin/rpm-install-helper install
    - unless: /usr/local/bin/rpm-install-helper check
    - shell: /bin/bash
    - runas: root
    - require:
      - file: rpm_install_helper
