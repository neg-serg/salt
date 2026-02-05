# Salt state for building and installing custom duf fork

/var/home/neg/src/duf_build:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

# Build duf from source using podman to keep host clean
build_custom_duf:
  cmd.run:
    - name: |
        podman run --rm -v /var/home/neg/src/duf_build:/build:Z registry.fedoraproject.org/fedora-toolbox:43 bash -c "
        dnf install -y git golang && 
        rm -rf /build/duf-src && 
        git clone https://github.com/neg-serg/duf.git /build/duf-src && 
        cd /build/duf-src && 
        git checkout 9eb104c275122f17c4b920fd75dc19bf0f3c0214 && 
        go build -ldflags="-s -w -X main.Version=0.9.1-neg" -o /build/duf-bin
        "
    - creates: /var/home/neg/src/duf_build/duf-bin
    - output_loglevel: info
    - runas: neg
    - require:
      - file: /var/home/neg/src/duf_build

install_custom_duf:
  file.managed:
    - name: /var/home/neg/.local/bin/duf
    - source: /var/home/neg/src/duf_build/duf-bin
    - mode: '0755'
    - user: neg
    - group: neg
    - require:
      - cmd: build_custom_duf
