# Declarative package management — installs all packages from data/packages.yaml
# Domain-specific packages (audio, fonts, steam, etc.) are managed by their own states.
# This state covers everything else: base system, desktop tools, dev tools, etc.
#
# Run: sudo salt-call --local state.apply packages
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% import_yaml 'data/packages.yaml' as pkgs %}

# ===================================================================
# Official repo packages (pacman) — one install per category
# ===================================================================

{% for category in ['base', 'desktop', 'dev', 'network', 'audio', 'media', 'fonts', 'gaming', 'system', 'other'] %}
{%- set pkg_list = pkgs.get(category, []) -%}
{%- if pkg_list %}
{{ pacman_install('pkg_' ~ category, pkg_list | join(' '), check=pkg_list[-1]) }}
{% endif %}
{%- endfor %}

# ===================================================================
# AUR packages (paru) — one install per package
# ===================================================================

{% for pkg in pkgs.get('aur', []) %}
{{ paru_install('pkg_aur_' ~ pkg, pkg) }}
{% endfor %}

# ===================================================================
# Auto-rebuild AUR packages broken by soname bumps (e.g. protobuf)
# ===================================================================

rebuild_broken_aur_packages:
  cmd.run:
    - name: |
        broken=$(checkrebuild 2>/dev/null | awk '{print $2}' | sort -u)
        if [ -z "$broken" ]; then
            echo "No broken packages"
            exit 0
        fi
        echo "Rebuilding broken AUR packages: $broken"
        sudo -u {{ _user }} paru -S --rebuild --noconfirm $broken
    - onlyif: checkrebuild 2>/dev/null | grep -q .
    - require:
      - cmd: install_pkg_system
