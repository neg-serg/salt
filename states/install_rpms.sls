# Salt state for custom RPM installation
# Installs all custom-built RPMs in a single rpm-ostree transaction

install_custom_rpms:
  cmd.run:
    - name: |
        {% raw %}
        RPM_DIR=/var/home/neg/src/salt/rpms
        shopt -s nullglob
        rpm_files=("$RPM_DIR"/*.rpm)
        [ ${#rpm_files[@]} -eq 0 ] && exit 0
        # Batch: get package names from all RPM files (one rpm call)
        mapfile -t pkg_names < <(rpm -qp --queryformat '%{NAME}\n' "${rpm_files[@]}" 2>/dev/null)
        # Batch: all installed packages (one rpm call)
        installed=$(rpm -qa --queryformat '%{NAME}\n' | sort -u)
        # Batch: all layered local packages (one rpm-ostree call)
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-local-packages"[]?')
        # Build lookup set
        declare -A have
        while IFS= read -r name; do [[ -n "$name" ]] && have["$name"]=1; done <<< "$installed"
        while IFS= read -r entry; do
          name="${entry%%-[0-9]*}"
          [[ -n "$name" ]] && have["$name"]=1
        done <<< "$layered"
        to_install=()
        for i in "${!pkg_names[@]}"; do
          [[ -z "${have[${pkg_names[$i]}]+x}" ]] && to_install+=("${rpm_files[$i]}")
        done
        if [ ${#to_install[@]} -gt 0 ]; then
          rpm-ostree install "${to_install[@]}"
        fi
        {% endraw %}
    - unless: |
        {% raw %}
        RPM_DIR=/var/home/neg/src/salt/rpms
        shopt -s nullglob
        rpm_files=("$RPM_DIR"/*.rpm)
        [ ${#rpm_files[@]} -eq 0 ] && exit 0
        rpm -q $(rpm -qp --queryformat '%{NAME} ' "${rpm_files[@]}" 2>/dev/null) > /dev/null 2>&1
        {% endraw %}
    - shell: /bin/bash
    - runas: root
