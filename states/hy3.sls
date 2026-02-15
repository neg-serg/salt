# Build and install hy3 Hyprland plugin (rootless, via podman)

/home/neg/.local/lib/hyprland:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

build_hy3:
  cmd.run:
    - name: >-
        podman run --rm
        -v /home/neg/src/salt/build:/build/salt:z
        -v /home/neg/.local/lib/hyprland:/build/output:z
        registry.fedoraproject.org/fedora-toolbox:43
        bash /build/salt/build-hy3.sh
    - runas: neg
    - creates: /home/neg/.local/lib/hyprland/libhy3.so
    - timeout: 600
    - require:
      - file: /home/neg/.local/lib/hyprland
