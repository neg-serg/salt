# Salt state for custom RPM installation
# Installs all custom-built RPMs in a single rpm-ostree transaction

install_custom_rpms:
  cmd.run:
    - name: |
        {% raw %}
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-local-packages"[]?')
        to_install=()
        for rpm_file in /var/home/neg/src/salt/rpms/*.rpm; do
          pkg_name=$(rpm -qp --queryformat '%{NAME}' "$rpm_file" 2>/dev/null)
          if ! rpm -q "$pkg_name" &>/dev/null && ! echo "$layered" | grep -q "^${pkg_name}-[0-9]"; then
            to_install+=("$rpm_file")
          fi
        done
        if [ ${#to_install[@]} -gt 0 ]; then
          rpm-ostree install "${to_install[@]}"
        fi
        {% endraw %}
    - unless: |
        {% raw %}
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-local-packages"[]?')
        for rpm_file in /var/home/neg/src/salt/rpms/*.rpm; do
          pkg_name=$(rpm -qp --queryformat '%{NAME}' "$rpm_file" 2>/dev/null)
          if ! rpm -q "$pkg_name" &>/dev/null && ! echo "$layered" | grep -q "^${pkg_name}-[0-9]"; then
            exit 1
          fi
        done
        {% endraw %}
    - runas: root
