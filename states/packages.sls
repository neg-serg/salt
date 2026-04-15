# Declarative package management — installs all packages from data/packages.yaml
# Domain-specific packages (audio, fonts, steam, etc.) are managed by their own states.
# This state covers everything else: base system, desktop tools, dev tools, etc.
#
# Run: sudo salt-call --local state.apply packages
{% from '_imports.jinja' import user %}
{% from '_macros_pkg.jinja' import paru_install %}
{% import_yaml 'data/packages.yaml' as pkgs %}

# ===================================================================
# Official repo packages (pacman) — one install per category
# ===================================================================

{% for category in ['base', 'desktop', 'dev', 'network', 'audio', 'media', 'fonts', 'gaming', 'system', 'other'] %}
{%- set pkg_list = pkgs.get(category, []) -%}
{%- if pkg_list %}
{#- pacman -Qq checks ALL packages — fails if ANY is missing, triggering install #}
{{ paru_install('pkg_' ~ category, pkg_list | join(' '), check='__ALL__') }}
{% endif %}
{%- endfor %}

# ===================================================================
# AUR packages (paru) — one install per package
# ===================================================================

{% for pkg in pkgs.get('aur', []) %}
{{ paru_install('pkg_aur_' ~ pkg, pkg) }}
{% endfor %}
