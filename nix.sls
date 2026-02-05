# Salt state for installing Nix using Determinate Nix Installer
# Specifically tailored for Fedora Silverblue (using /var/nix symlink)

nix_dir_var:
  file.directory:
    - name: /var/nix
    - user: root
    - group: root
    - mode: '0755'

nix_tmpfile:
  file.managed:
    - name: /etc/tmpfiles.d/nix.conf
    - contents: |
        L  /nix  -  -  -  -  /var/nix
    - user: root
    - group: root
    - mode: '0644'

apply_nix_tmpfile:
  cmd.run:
    - name: systemd-tmpfiles --create /etc/tmpfiles.d/nix.conf
    - onchanges:
      - file: nix_tmpfile
    - unless: test -L /nix

install_determinate_nix:
  cmd.run:
    - name: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
    - unless: command -v nix
    - require:
      - cmd: apply_nix_tmpfile
