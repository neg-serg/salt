{% from '_imports.jinja' import user, home, retry_attempts, retry_interval %}
{% from '_macros_install.jinja' import cargo_pkg, curl_bin, curl_extract_tar, curl_extract_zip, git_clone_deploy, http_file, pip_pkg %}
{% from '_macros_github.jinja' import github_tar %}
{% from '_macros_pkg.jinja' import paru_install %}
{% import_yaml 'data/installers.yaml' as tools %}
{% import_yaml 'data/versions.yaml' as ver %}

# ===========================================================================
# Data-driven fallback installs (definitions in data/installers.yaml)
# Use only when no official/AUR package is suitable.
# ===========================================================================

# --- Direct binary downloads to ~/.local/bin/ ---
{% for name, raw in tools.curl_bin.items() %}
{% set _v = ver.get(name | replace('-', '_'), '') %}
{% if raw is mapping %}
{% set resolved_url = raw.url | replace('${VER}', _v) %}
{{ curl_bin(name, resolved_url, version=_v if _v else None, hash=raw.get('hash')) }}
{% else %}
{% set resolved_url = raw | replace('${VER}', _v) %}
{{ curl_bin(name, resolved_url, version=_v if _v else None) }}
{% endif %}
{% endfor %}

# --- GitHub tar.gz archives ---
{% for name, raw in tools.github_tar.items() %}
{% set _v = ver.get(name | replace('-', '_'), '') %}
{% if raw is mapping %}
{% set resolved_url = raw.url | replace('${VER}', _v) %}
{{ github_tar(name, resolved_url, version=_v if _v else None, hash=raw.get('hash')) }}
{% else %}
{% set resolved_url = raw | replace('${VER}', _v) %}
{{ github_tar(name, resolved_url, version=_v if _v else None) }}
{% endif %}
{% endfor %}

# --- pip installs (pipx) ---
{% for name, opts in tools.pip_pkg.items() %}
{{ pip_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin')) }}
{% endfor %}

# --- cargo installs ---
{% for name, opts in tools.cargo_pkg.items() %}
{{ cargo_pkg(name, pkg=opts.get('pkg'), bin=opts.get('bin'), git=opts.get('git')) }}
{% endfor %}

# --- ZIP archive extractions ---
{% for name, opts in tools.curl_extract_zip.items() %}
{% set _v = ver.get(name, '') %}
{% set resolved_url = opts.url | replace('${VER}', _v) %}
{{ curl_extract_zip(name, resolved_url, opts.binary_path, binaries=opts.get('binaries'), chmod=opts.get('chmod', False), hash=opts.get('hash'), version=_v if _v else None) }}
{% endfor %}

# --- tar.gz archive extractions ---
{% set skip_tar_installs = ['essentia'] %}
{% for name, opts in tools.get('curl_extract_tar', {}).items() %}
{% if name not in skip_tar_installs %}
{% set _v = ver.get(name, '') %}
{% set resolved_url = opts.url | replace('${VER}', _v) %}
{{ curl_extract_tar(name, resolved_url, binary_pattern=opts.binary_pattern, bin=opts.get('bin'), hash=opts.get('hash'), version=_v if _v else None) }}
{% endif %}
{% endfor %}

# ===========================================================================
# AUR package installs (migrated from manual downloads)
# ===========================================================================
{{ paru_install('tdl', 'tdl-bin') }}

# One-time cleanup: remove old manually-installed binary
tdl_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/tdl
    - onlyif: test -f {{ home }}/.local/bin/tdl

# ===========================================================================
# Custom installs (not data-driven — unique logic or version interpolation)
# ===========================================================================

# --- Shell frameworks ---
{{ git_clone_deploy('zi', 'https://github.com/z-shell/zi.git', '~/.config/zi/bin', creates=home ~ '/.config/zi/bin/zi.zsh', user=user, home=home) }}

# --- Hyprland tools (multi-binary) ---
{{ curl_extract_tar('hyprevents', 'https://github.com/vilari-mickopf/hyprevents/archive/refs/heads/master.tar.gz', 'hyprevents-master', binaries=['hyprevents', 'event_handler', 'event_loader'], chmod=True) }}

# --- aider (AI coding assistant) ---
{# {{ paru_install('aider', 'aider-chat') }} #}

# One-time cleanup: remove old uv-installed binary after package migration
aider_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/aider
    - onlyif: test -f {{ home }}/.local/bin/aider

# --- pip: dr14_tmeter (custom git install, needs GIT_CONFIG_GLOBAL override) ---
{{ pip_pkg('dr14_tmeter', pkg='git+https://github.com/simon-r/dr14_t.meter.git', env='GIT_CONFIG_GLOBAL=/dev/null') }}

# tailray: migrated to PKGBUILD (build/pkgbuilds/tailray/)

{{ http_file('qmk_udev_rules', 'https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules', '/etc/udev/rules.d/50-qmk.rules', mode='0644', user=None, parallel=False) }}

qmk_udev_rules_reload:
  cmd.run:
    - name: udevadm control --reload-rules
    - onlyif: command -v udevadm >/dev/null 2>&1
    - onchanges:
      - cmd: qmk_udev_rules

# --- blesh (Bash Line Editor) ---
{{ curl_extract_tar('blesh', 'https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz', archive_ext='tar.xz', dest='~/.local/share', strip_components=1, creates=home ~ '/.local/share/ble.sh', user=user, home=home) }}
