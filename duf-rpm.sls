# Salt state for Custom Duf RPM installation

install_duf_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/duf-*.rpm
    - unless: "rpm-ostree status | grep 'duf-'" # Check for custom duf RPM
    - runas: root # rpm-ostree needs root

install_massren_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/massren-*.rpm
    - unless: "rpm-ostree status | grep 'massren-'"
    - runas: root

install_raise_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/raise-*.rpm
    - unless: "rpm-ostree status | grep 'raise-'"
    - runas: root

install_pipemixer_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/pipemixer-*.rpm
    - unless: "rpm-ostree status | grep 'pipemixer-'"
    - runas: root

install_richcolors_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/richcolors-*.rpm
    - unless: "rpm-ostree status | grep 'richcolors-'"
    - runas: root

install_neg_pretty_printer_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/neg-pretty-printer-*.rpm
    - unless: "rpm-ostree status | grep 'neg-pretty-printer-'"
    - runas: root
