# Salt state for Custom Iosevka build and deploy

{% set iosevka_config = salt['file.read']('/var/home/neg/src/salt/iosevka-neg.toml') %}

/var/home/neg/src/iosevka_build:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

/var/home/neg/.local/share/fonts/Iosevka:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

# Manage the build plan as a separate file to avoid shell quoting issues
/var/home/neg/src/iosevka_build/private-build-plans.toml:
  file.managed:
    - contents: |
{{ iosevka_config | indent(8, True) }}
    - user: neg
    - group: neg
    - require:
      - file: /var/home/neg/src/iosevka_build

# Build Iosevka
# Using node:22-slim for a stable build environment
build_iosevka:
  cmd.run:
    - name: |
        podman run --rm -v /var/home/neg/src/iosevka_build:/build:Z node:22-slim bash -c "
        set -e
        apt-get update && apt-get install -y git ttfautohint
        git clone --depth 1 https://github.com/be5invis/Iosevka.git /iosevka
        cd /iosevka
        cp /build/private-build-plans.toml .
        npm install
        npm run build -- contents::Iosevkaneg
        mkdir -p /build/ttf
        rm -rf /build/ttf/*
        cp -v dist/Iosevkaneg/TTF/*.ttf /build/ttf/
        "
    - runas: neg
    - creates: /var/home/neg/src/iosevka_build/ttf/Iosevka-Regular.ttf
    - timeout: 7200
    - output_loglevel: info
    - require:
      - file: /var/home/neg/src/iosevka_build/private-build-plans.toml

# Patch Iosevka with Nerd Font
patch_iosevka:
  cmd.run:
    - name: |
        mkdir -p /var/home/neg/src/iosevka_build/nerd-fonts
        rm -rf /var/home/neg/src/iosevka_build/nerd-fonts/*
        podman run --rm -v /var/home/neg/src/iosevka_build:/build:Z docker.io/nerdfonts/patcher --complete --quiet --outputdir /build/nerd-fonts /build/ttf/Iosevka-Regular.ttf
        podman run --rm -v /var/home/neg/src/iosevka_build:/build:Z docker.io/nerdfonts/patcher --complete --quiet --outputdir /build/nerd-fonts /build/ttf/Iosevka-Bold.ttf
        podman run --rm -v /var/home/neg/src/iosevka_build:/build:Z docker.io/nerdfonts/patcher --complete --quiet --outputdir /build/nerd-fonts /build/ttf/Iosevka-Italic.ttf
        podman run --rm -v /var/home/neg/src/iosevka_build:/build:Z docker.io/nerdfonts/patcher --complete --quiet --outputdir /build/nerd-fonts /build/ttf/Iosevka-BoldItalic.ttf
    - runas: neg
    - creates: /var/home/neg/src/iosevka_build/nerd-fonts/IosevkaNerdFont-Regular.ttf
    - require:
      - cmd: build_iosevka

# Install fonts
install_iosevka_fonts:
  cmd.run:
    - name: |
        cp -v /var/home/neg/src/iosevka_build/nerd-fonts/*.ttf /var/home/neg/.local/share/fonts/Iosevka/
        fc-cache -f /var/home/neg/.local/share/fonts/Iosevka
    - runas: neg
    - onchanges:
      - cmd: patch_iosevka
    - require:
      - file: /var/home/neg/.local/share/fonts/Iosevka