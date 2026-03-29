{% from '_imports.jinja' import host %}
{% from '_macros_config.jinja' import config_file_edit %}
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

# --- Restructure limine.conf for flat boot entries ---
# Moves //CachyOS LTS from inside /CachyOS directory to a flat top-level entry.
# This fixes timeout auto-boot: flat entries boot directly, directories open submenus.
limine_flat_boot_entries:
  cmd.script:
    - source: salt://scripts/limine-restructure.sh
    - shell: /bin/bash
    - unless: grep -q '^/CachyOS LTS' /boot/limine.conf

# Deploy limine-set-default convenience script.
limine_set_default_deployed:
  file.managed:
    - name: /usr/local/bin/limine-set-default
    - source: salt://scripts/limine-set-default.sh
    - mode: '0755'

# Set bootloader timeout to 1 second — enough to catch the menu on panic,
# fast enough to not delay normal boot.
{{ config_file_edit('limine_timeout',
    cmd="sed -i 's/^timeout:.*/timeout: 1/' /boot/limine.conf",
    check_pattern='^timeout: 1$',
    check_file='/boot/limine.conf',
    require=['cmd: limine_flat_boot_entries']) }}

# Append missing kernel params to all kernel_cmdline entries in limine.conf.
# Preserves existing root= and other boot-critical params.
kernel_params_limine:
  cmd.run:
    - shell: /bin/bash
    - name: |
        LIMINE="/boot/limine.conf"
        WANTED=({% for karg in kargs %}'{{ karg }}' {% endfor %})

        # Build space-separated string of params not already present
        current=$(grep 'kernel_cmdline:' "$LIMINE" | head -1)
        missing=""
        for k in "${WANTED[@]}"; do
          # Match param key (before =) to avoid partial matches
          key="${k%%=*}"
          if ! grep -q "$key" <<< "$current"; then
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
          grep -q "$key" <<< "$current" || exit 1
        done
    - require:
      - cmd: limine_flat_boot_entries

# --- limine-snapper-sync: fix CachyOS-specific paths and OS name ---
limine_snapper_sync_config:
  cmd.run:
    - shell: /bin/bash
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
        grep -q '^TARGET_OS_NAME="CachyOS"' "$CONF" &&
        grep -q '^ROOT_SNAPSHOTS_PATH="/@snapshots"' "$CONF" &&
        ! grep -q '^COMMANDS_BEFORE_SAVE=' "$CONF" &&
        ! grep -q '^COMMANDS_AFTER_SAVE=' "$CONF"

# Ensure limine.conf uses multi-profile format (required for snapshot boot entries).
# Fails the state run to prevent silent misconfiguration.
limine_multiprofile_check:
  cmd.run:
    - name: |
        echo "ERROR: limine.conf needs //KernelName sub-entries for snapshot sync" >&2
        echo "  See: https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md" >&2
        exit 1
    - onlyif: |
        [ -f /boot/limine.conf ] &&
        ! grep -q '^    //' /boot/limine.conf
    - require:
      - cmd: limine_flat_boot_entries
