{% from '_imports.jinja' import user, home, pkg_list, retry_attempts, retry_interval %}
{% from '_macros_install.jinja' import curl_bin, curl_extract_tar, curl_extract_zip %}
{% from '_macros_pkg.jinja' import paru_install %}
{% import_yaml 'data/installers_desktop.yaml' as apps %}
{% import_yaml 'data/versions.yaml' as ver %}
# Desktop application installers: GUI apps, AppImages, AUR packages
# Definitions in data/installers_desktop.yaml; adding/updating is a YAML-only edit.

# --- ZIP archives (app bundles + binaries) ---
{% for name, opts in apps.curl_extract_zip.items() %}
{% set _v = ver.get(name, '') %}
{% set url = opts.url | replace('${VER}', _v) %}
{{ curl_extract_zip(name, url, binary_path=opts.get('binary_path'), binaries=opts.get('binaries'), chmod=opts.get('chmod', False), dest=opts.get('dest'), symlink=opts.get('symlink'), hash=opts.get('hash'), version=_v if _v else None, user=user, home=home) }}
{% endfor %}

# --- tar.gz archives ---
{% for name, opts in apps.curl_extract_tar.items() %}
{% set _v = ver.get(name, '') %}
{% set url = opts.url | replace('${VER}', _v) %}
{{ curl_extract_tar(name, url, opts.binary_pattern, bin=opts.get('bin'), chmod=opts.get('chmod', False), hash=opts.get('hash'), version=_v if _v else None, user=user, home=home) }}
{% endfor %}

# --- Direct binary downloads ---
{% for name, raw in apps.curl_bin.items() %}
{% set _v = ver.get(name, '') %}
{% if raw is mapping %}
{% set resolved_url = raw.url | replace('${VER}', _v) %}
{{ curl_bin(name, resolved_url, version=_v if _v else None, hash=raw.get('hash'), user=user, home=home) }}
{% else %}
{% set resolved_url = raw | replace('${VER}', _v) %}
{{ curl_bin(name, resolved_url, version=_v if _v else None, user=user, home=home) }}
{% endif %}
{% endfor %}

# --- AUR packages (v4l2loopback-dkms for droidcam installed via pacman outside Salt) ---
{% for name, pkg in apps.paru_install.items() %}
{{ paru_install(name, pkg) }}
{% endfor %}

# rofi-file-browser-extended: needs PKGBUILD patching for CMake 4.0 + GCC 15 compat.
# - CMake 4.0 removed cmake_minimum_required < 3.5 support
# - GCC 15 made -Wincompatible-pointer-types a hard error (rofi API signature mismatch)
# Can't use env vars — makepkg.conf overwrites CFLAGS. Patch build() directly.
rofi_file_browser_extended:
  cmd.run:
    - name: |
        set -eo pipefail
        BUILDDIR=$(sudo -u {{ user }} mktemp -d)
        trap 'rm -rf "$BUILDDIR"' EXIT
        cd "$BUILDDIR"
        sudo -u {{ user }} paru -G rofi-file-browser-extended-git
        cd rofi-file-browser-extended-git
        sed -i '/^build()/a\  export CMAKE_POLICY_VERSION_MINIMUM=3.5\n  export CFLAGS="${CFLAGS} -Wno-error=incompatible-pointer-types"' PKGBUILD
        sudo -u {{ user }} makepkg -sf --noconfirm
        pacman -U --noconfirm --needed *.pkg.tar.zst
    - shell: /bin/bash
    - unless: rg -qx 'rofi-file-browser-extended-git' {{ pkg_list }}
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
    - require:
      - cmd: pacman_db_warmup
