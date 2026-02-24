# Salt state to build and install custom packages from local PKGBUILDs
# These packages are not in official repos or AUR and require local builds
{% from '_imports.jinja' import host, user, home, pkg_list %}
{% from '_macros_pkg.jinja' import pkgbuild_install %}
{% import_yaml 'data/custom_pkgs.yaml' as custom %}

{% for name, opts in custom.pkgbuild.items() %}
{% set opts = opts or {} %}
{{ pkgbuild_install(name, 'salt://build/pkgbuilds/' ~ name, user=user,
     timeout=opts.get('timeout', 600),
     replace_check=opts.get('replace_check'),
     extra_sources=opts.get('extra_sources')) }}
{% endfor %}
