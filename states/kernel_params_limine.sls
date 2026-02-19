{% from '_imports.jinja' import host, user, home %}
# Kernel boot parameters for CachyOS (Limine bootloader).
# Manages kernel_cmdline entries in /boot/limine.conf.
#
# Applied by editing kernel_cmdline in limine.conf. Requires reboot.
# Run: sudo salt-call --local -c .salt_runtime state.sls kernel_params_limine

{% import_yaml 'data/kernel_params.yaml' as kp %}

{# Assemble kargs from data file + host-specific conditionals #}
{% set kargs = kp.common[:] %}
{% if host.cpu_vendor == 'amd' %}
{% do kargs.extend(kp.amd) %}
{% elif host.cpu_vendor == 'intel' %}
{% do kargs.extend(kp.intel) %}
{% endif %}
{% if host.display %}
{% do kargs.append('video=' ~ host.display) %}
{% endif %}
{% if not host.is_laptop %}
{% do kargs.extend(kp.desktop) %}
{% endif %}
{% if host.is_laptop %}
{% do kargs.extend(kp.laptop) %}
{% endif %}
{% for karg in host.extra_kargs %}
{% do kargs.append(karg) %}
{% endfor %}

# Append missing kernel params to all kernel_cmdline entries in limine.conf.
# Preserves existing root= and other boot-critical params.
set_kernel_params_limine:
  cmd.run:
    - name: |
        LIMINE="/boot/limine.conf"
        WANTED=({% for karg in kargs %}'{{ karg }}' {% endfor %})

        # Build space-separated string of params not already present
        current=$(grep 'kernel_cmdline:' "$LIMINE" | head -1)
        missing=""
        for k in "${WANTED[@]}"; do
          # Match param key (before =) to avoid partial matches
          key="${k%%=*}"
          if ! rg -q "$key" <<< "$current"; then
            missing="$missing $k"
          fi
        done

        if [ -z "$missing" ]; then
          echo "All kernel params already present"
          exit 0
        fi

        echo "Adding kernel params:$missing"
        # Append to every kernel_cmdline line (primary + fallback entries)
        sed -i "s|^\(    kernel_cmdline:.*\)|\1$missing|" "$LIMINE"
    - unless: |
        LIMINE="/boot/limine.conf"
        WANTED=({% for karg in kargs %}'{{ karg }}' {% endfor %})
        current=$(grep 'kernel_cmdline:' "$LIMINE" | head -1)
        for k in "${WANTED[@]}"; do
          key="${k%%=*}"
          rg -q "$key" <<< "$current" || exit 1
        done

# --- limine-snapper-sync: fix CachyOS-specific paths and OS name ---
limine_snapper_sync_config:
  cmd.run:
    - name: |
        set -eo pipefail
        CONF="/etc/limine-snapper-sync.conf"
        [ -f "$CONF" ] || exit 0
        sed -i \
          -e 's|^#\?TARGET_OS_NAME=.*|TARGET_OS_NAME="CachyOS"|' \
          -e 's|^ROOT_SNAPSHOTS_PATH="/@/.snapshots"|ROOT_SNAPSHOTS_PATH="/@snapshots"|' \
          -e 's|^COMMANDS_BEFORE_SAVE=|#COMMANDS_BEFORE_SAVE=|' \
          -e 's|^COMMANDS_AFTER_SAVE=|#COMMANDS_AFTER_SAVE=|' \
          "$CONF"
    - unless: |
        CONF="/etc/limine-snapper-sync.conf"
        [ -f "$CONF" ] || exit 0
        rg -q '^TARGET_OS_NAME="CachyOS"' "$CONF" &&
        rg -q '^ROOT_SNAPSHOTS_PATH="/@snapshots"' "$CONF" &&
        ! rg -q '^COMMANDS_BEFORE_SAVE=' "$CONF" &&
        ! rg -q '^COMMANDS_AFTER_SAVE=' "$CONF"

# Ensure limine.conf uses multi-profile format (required for snapshot boot entries)
limine_multiprofile_check:
  cmd.run:
    - name: echo "WARNING - limine.conf needs //KernelName sub-entries for snapshot sync"
    - onlyif: |
        [ -f /boot/limine.conf ] &&
        ! rg -q '^    //' /boot/limine.conf
