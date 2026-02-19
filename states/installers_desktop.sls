{% from '_imports.jinja' import host, user, home %}
{% from '_macros_install.jinja' import curl_bin, curl_extract_zip, curl_extract_tar %}
{% from '_macros_pkg.jinja' import paru_install %}
{% import_yaml 'data/installers_desktop.yaml' as apps %}
{% import_yaml 'data/versions.yaml' as ver %}
# Desktop application installers: GUI apps, AppImages, AUR packages
# Definitions in data/installers_desktop.yaml; adding/updating is a YAML-only edit.

# --- ZIP archives (app bundles + binaries) ---
{% for name, opts in apps.curl_extract_zip.items() %}
{% set url = opts.url | replace('${VER}', ver.get(name, '')) %}
{{ curl_extract_zip(name, url, binary_path=opts.get('binary_path'), binaries=opts.get('binaries'), chmod=opts.get('chmod', False), dest=opts.get('dest'), symlink=opts.get('symlink'), user=user, home=home) }}
{% endfor %}

# --- tar.gz archives ---
{% for name, opts in apps.curl_extract_tar.items() %}
{% set url = opts.url | replace('${VER}', ver.get(name, '')) %}
{{ curl_extract_tar(name, url, opts.binary_pattern, bin=opts.get('bin'), chmod=opts.get('chmod', False), user=user, home=home) }}
{% endfor %}

# --- Direct binary downloads ---
{% for name, url in apps.curl_bin.items() %}
{% set resolved_url = url | replace('${VER}', ver.get(name, '')) %}
{{ curl_bin(name, resolved_url, user=user, home=home) }}
{% endfor %}

# --- AUR packages (v4l2loopback-dkms for droidcam installed via pacman outside Salt) ---
{% for name, pkg in apps.paru_install.items() %}
{{ paru_install(name, pkg) }}
{% endfor %}

# rofi-file-browser-extended: needs workarounds for CMake 4.0 (cmake_minimum_required < 3.5)
# and GCC 15 (incompatible-pointer-types is now an error due to rofi API signature change)
install_rofi_file_browser_extended:
  cmd.run:
    - name: sudo -u {{ user }} env CMAKE_POLICY_VERSION_MINIMUM=3.5 CFLAGS="-Wno-error=incompatible-pointer-types" paru -S --noconfirm --needed rofi-file-browser-extended-git
    - unless: |
        C=/var/cache/salt/pacman_installed.txt
        [ -f "$C" ] || pacman -Qq > "$C"
        rg -qx 'rofi-file-browser-extended-git' "$C"
    - require:
      - cmd: pacman_db_warmup
