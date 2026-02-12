# Salt state for custom RPM installation
# Installs all custom-built RPMs in a single rpm-ostree transaction

install_custom_rpms:
  cmd.run:
    - name: |
        {% raw %}
        RPM_DIR=/var/home/neg/src/salt/rpms
        shopt -s nullglob
        all_rpms=("$RPM_DIR"/*.rpm)
        # Filter out debuginfo/debugsource packages
        rpm_files=()
        for f in "${all_rpms[@]}"; do
          case "${f##*/}" in *-debuginfo-*|*-debugsource-*) continue;; esac
          rpm_files+=("$f")
        done
        [ ${#rpm_files[@]} -eq 0 ] && exit 0
        # Batch: get package name.arch from all RPM files (one rpm call)
        mapfile -t pkg_ids < <(rpm -qp --queryformat '%{NAME}.%{ARCH}\n' "${rpm_files[@]}" 2>/dev/null)
        # Batch: all installed packages by name.arch (one rpm call)
        installed=$(rpm -qa --queryformat '%{NAME}.%{ARCH}\n' | sort -u)
        # Batch: all layered local packages (one rpm-ostree call)
        layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-local-packages"[]?')
        # Build lookup set keyed by name.arch
        declare -A have
        while IFS= read -r id; do [[ -n "$id" ]] && have["$id"]=1; done <<< "$installed"
        while IFS= read -r entry; do
          [[ -z "$entry" ]] && continue
          arch="${entry##*.}"
          name="${entry%%-[0-9]*}"
          [[ -n "$name" && -n "$arch" ]] && have["${name}.${arch}"]=1
        done <<< "$layered"
        to_install=()
        for i in "${!pkg_ids[@]}"; do
          [[ -z "${have[${pkg_ids[$i]}]+x}" ]] && to_install+=("${rpm_files[$i]}")
        done
        if [ ${#to_install[@]} -gt 0 ]; then
          rpm-ostree install "${to_install[@]}"
        fi
        {% endraw %}
    - unless: |
        {% raw %}
        RPM_DIR=/var/home/neg/src/salt/rpms
        shopt -s nullglob
        all_rpms=("$RPM_DIR"/*.rpm)
        rpm_files=()
        for f in "${all_rpms[@]}"; do
          case "${f##*/}" in *-debuginfo-*|*-debugsource-*) continue;; esac
          rpm_files+=("$f")
        done
        [ ${#rpm_files[@]} -eq 0 ] && exit 0
        mapfile -t ids < <(rpm -qp --queryformat '%{NAME}.%{ARCH}\n' "${rpm_files[@]}" 2>/dev/null)
        for id in "${ids[@]}"; do rpm -q --queryformat '' "$id" 2>/dev/null || exit 1; done
        {% endraw %}
    - shell: /bin/bash
    - runas: root
