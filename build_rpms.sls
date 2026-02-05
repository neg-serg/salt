# Salt state for building custom RPMs (Iosevka and Duf)

/var/home/neg/src/salt/rpms:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

# This state runs the build-rpm.sh script inside a container
# to produce the RPM packages.
build_custom_rpms:
  cmd.run:
    - name: |
        podman run --rm -v /var/home/neg/src/salt:/build:Z \
        registry.fedoraproject.org/fedora-toolbox:43 \
        /build/build-rpm.sh
    - runas: neg # Run as user 'neg' for rootless podman and user ownership of files
    - creates: /var/home/neg/src/salt/rpms/iosevka-neg-fonts-*.rpm # Indicate creation of Iosevka RPM
    - creates: /var/home/neg/src/salt/rpms/duf-*.rpm # Indicate creation of Duf RPM
    - timeout: 7200 # Allow up to 2 hours for build
    - output_loglevel: info
    - require:
      - file: /var/home/neg/src/salt/rpms
