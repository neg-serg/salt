# Declarative package management — installs all packages from data/packages.yaml
# Domain-specific packages (audio, fonts, steam, etc.) are managed by their own states.
# This state covers everything else: base system, desktop tools, dev tools, etc.
#
# Run: sudo salt-call --local state.apply packages
{% from '_macros_pkg.jinja' import pacman_install, paru_install %}
{% from '_macros_common.jinja' import user %}
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
        # Exclude packages that bundle their own private libs (false positives):
        #   proton-ge-custom-bin — bundles libvpx.so.6/libwebp.so.6 in its own prefix;
        #     loaded via LD_LIBRARY_PATH at runtime, not from system lib path.
        broken=$(checkrebuild 2>/dev/null | awk '{print $2}' | grep -v '^proton-ge-custom-bin$' | sort -u)
        if [ -z "$broken" ]; then
            echo "No broken packages"
        else
            echo "Rebuilding broken AUR packages: $broken"
            sudo -u {{ user }} paru -S --rebuild --noconfirm $broken
        fi
        touch /var/cache/salt/checkrebuild.stamp
    - onlyif: "[ /var/lib/pacman/local -nt /var/cache/salt/checkrebuild.stamp ]"
    - require:
      - cmd: install_pkg_system
