# Salt state for Custom Duf RPM installation

install_duf_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/duf-*.rpm
    - unless: "rpm-ostree status | grep 'duf-'" # Check for custom duf RPM
    - runas: root # rpm-ostree needs root
