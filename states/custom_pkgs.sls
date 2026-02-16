# Salt state to build and install custom packages from local PKGBUILDs
# These packages are not in official repos or AUR and require local builds
{% from 'host_config.jinja' import host %}
{% set user = host.user %}
{% set build_base = '/tmp/pkgbuild' %}

# --- Simple PKGBUILDs (self-contained, download source from GitHub) ---
{% set simple_pkgs = ['raise', 'richcolors', 'albumdetails'] %}

{% for pkg in simple_pkgs %}
{% set safe = pkg | replace('-', '_') %}
{{ safe }}_pkgbuild:
  file.recurse:
    - name: {{ build_base }}/{{ pkg }}
    - source: salt://build/pkgbuilds/{{ pkg }}
    - makedirs: True
    - user: {{ user }}
    - group: {{ user }}

build_{{ safe }}:
  cmd.run:
    - name: |
        set -eo pipefail
        su - {{ user }} -c 'cd {{ build_base }}/{{ pkg }} && makepkg -sf --noconfirm'
        pacman -U --noconfirm --needed {{ build_base }}/{{ pkg }}/*.pkg.tar.zst
        rm -rf {{ build_base }}/{{ pkg }}
    - shell: /bin/bash
    - timeout: 600
    - unless: pacman -Q {{ pkg }}
    - require:
      - file: {{ safe }}_pkgbuild

{% endfor %}
# --- duf (neg-serg fork with --style plain, replaces stock duf) ---
duf_pkgbuild:
  file.recurse:
    - name: {{ build_base }}/duf
    - source: salt://build/pkgbuilds/duf
    - makedirs: True
    - user: {{ user }}
    - group: {{ user }}

build_duf:
  cmd.run:
    - name: |
        set -eo pipefail
        if pacman -Q duf &>/dev/null && ! pacman -Qi duf 2>/dev/null | grep -q 'neg-serg'; then
            pacman -Rdd --noconfirm duf
        fi
        su - {{ user }} -c 'cd {{ build_base }}/duf && makepkg -sf --noconfirm'
        pacman -U --noconfirm {{ build_base }}/duf/*.pkg.tar.zst
        rm -rf {{ build_base }}/duf
    - shell: /bin/bash
    - timeout: 600
    - unless: pacman -Qi duf 2>/dev/null | grep -q neg-serg
    - require:
      - file: duf_pkgbuild

# --- neg-pretty-printer (needs local source from build/pretty-printer/) ---
neg_pretty_printer_pkgbuild:
  file.recurse:
    - name: {{ build_base }}/neg-pretty-printer
    - source: salt://build/pkgbuilds/neg-pretty-printer
    - makedirs: True
    - user: {{ user }}
    - group: {{ user }}

neg_pretty_printer_source:
  file.recurse:
    - name: /tmp/pretty-printer
    - source: salt://build/pretty-printer
    - makedirs: True
    - user: {{ user }}
    - group: {{ user }}

build_neg_pretty_printer:
  cmd.run:
    - name: |
        set -eo pipefail
        su - {{ user }} -c 'cd {{ build_base }}/neg-pretty-printer && makepkg -sf --noconfirm'
        pacman -U --noconfirm --needed {{ build_base }}/neg-pretty-printer/*.pkg.tar.zst
        rm -rf {{ build_base }}/neg-pretty-printer /tmp/pretty-printer
    - shell: /bin/bash
    - timeout: 600
    - unless: pacman -Q neg-pretty-printer
    - require:
      - file: neg_pretty_printer_pkgbuild
      - file: neg_pretty_printer_source
