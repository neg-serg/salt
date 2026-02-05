# Salt state for Custom Iosevka RPM installation

/var/home/neg/.local/share/fonts/Iosevka:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

install_iosevka_rpm:
  cmd.run:
    - name: |
        rpm-ostree install /var/home/neg/src/salt/rpms/iosevka-neg-fonts-*.rpm
        fc-cache -f
    - unless: "rpm-ostree status | grep 'iosevka-neg-fonts'" # Check if already layered
    - runas: root # rpm-ostree needs root
    - require:
      - file: /var/home/neg/.local/share/fonts/Iosevka