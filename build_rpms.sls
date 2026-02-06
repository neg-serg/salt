# Salt state for building custom RPMs (Iosevka and Duf)

/var/home/neg/src/salt/rpms:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

# Build Duf RPM
build_duf_rpm:
  cmd.run:
    - name: |
        podman run --rm \
        -v /var/home/neg/src/salt/salt:/build/salt:z \
        -v /var/home/neg/src/salt/rpms:/build/rpms:z \
        registry.fedoraproject.org/fedora-toolbox:43 \
        bash /build/salt/build-rpm.sh duf
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/duf-0.9.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

# Build Massren RPM
build_massren_rpm:
  cmd.run:
    - name: |
        podman run --rm \
        -v /var/home/neg/src/salt/salt:/build/salt:z \
        -v /var/home/neg/src/salt/rpms:/build/rpms:z \
        registry.fedoraproject.org/fedora-toolbox:43 \
        bash /build/salt/build-rpm.sh massren
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/massren-1.5.6-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

# Build Raise RPM
build_raise_rpm:
  cmd.run:
    - name: |
        podman run --rm \
        -v /var/home/neg/src/salt/salt:/build/salt:z \
        -v /var/home/neg/src/salt/rpms:/build/rpms:z \
        registry.fedoraproject.org/fedora-toolbox:43 \
        bash /build/salt/build-rpm.sh raise
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/raise-0.1.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

# Build Iosevka RPM
build_iosevka_rpm:
  cmd.run:
    - name: |
        podman run --rm \
        -v /var/home/neg/src/salt/salt:/build/salt:z \
        -v /var/home/neg/src/salt/rpms:/build/rpms:z \
        -v /var/home/neg/src/salt/iosevka-neg.toml:/build/iosevka-neg.toml:z \
        registry.fedoraproject.org/fedora-toolbox:43 \
        bash /build/salt/build-rpm.sh iosevka
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/iosevka-neg-fonts-34.1.0-1.fc43.noarch.rpm
    - timeout: 7200
    - output_loglevel: info
    - require:
      - file: /var/home/neg/src/salt/rpms