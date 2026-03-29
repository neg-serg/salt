# Salt state to build and install custom packages from local PKGBUILDs
# These packages are not in official repos or AUR and require local builds
{% from '_imports.jinja' import user %}
{% from '_macros_pkg.jinja' import pkgbuild_install %}
{% import_yaml 'data/custom_pkgs.yaml' as custom %}

# --- Protect forked packages from pacman -Syu overwrite ---
# Packages with replace_check are local forks that conflict with stock names;
# IgnorePkg prevents pacman from replacing them with repo versions.
{% set fork_names = [] %}
{% for name, opts in custom.pkgbuild.items() %}
{%   if (opts or {}).get('replace_check') %}
{%     do fork_names.append(name) %}
{%   endif %}
{% endfor %}
{% if fork_names %}
pacman_ignore_forks:
  file.replace:
    - name: /etc/pacman.conf
    - pattern: '^#?\s*IgnorePkg\s*=.*'
    - repl: 'IgnorePkg = {{ fork_names | sort | join(' ') }}'
    - count: 1
{% endif %}

{% for name, opts in custom.pkgbuild.items() %}
{% set opts = opts or {} %}
{{ pkgbuild_install(name, 'salt://build/pkgbuilds/' ~ name, user=user,
     timeout=opts.get('timeout', 600),
     replace_check=opts.get('replace_check'),
     conflicts=opts.get('conflicts'),
     extra_sources=opts.get('extra_sources')) }}
{% endfor %}
