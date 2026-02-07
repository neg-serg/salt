# Salt state for custom RPM installation
# Installs all custom-built RPMs in a single rpm-ostree transaction

install_custom_rpms:
  cmd.run:
    - name: |
        {% raw %}
        to_install=()
        for rpm_file in /var/home/neg/src/salt/rpms/*.rpm; do
          pkg_name=$(rpm -qp --queryformat '%{NAME}' "$rpm_file" 2>/dev/null)
          if ! rpm -q "$pkg_name" &>/dev/null; then
            to_install+=("$rpm_file")
          fi
        done
        if [ ${#to_install[@]} -gt 0 ]; then
          rpm-ostree install "${to_install[@]}"
        fi
        {% endraw %}
    - unless: |
        for rpm_file in /var/home/neg/src/salt/rpms/*.rpm; do
          pkg_name=$(rpm -qp --queryformat '%{NAME}' "$rpm_file" 2>/dev/null)
          if ! rpm -q "$pkg_name" &>/dev/null; then
            exit 1
          fi
        done
    - runas: root
