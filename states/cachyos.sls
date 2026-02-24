{% from '_imports.jinja' import host, user, home %}
{% import_yaml 'data/cachyos.yaml' as checks %}
# CachyOS bootstrap verification state
# Validates that bootstrap-cachyos.sh + cachyos-packages.sh completed correctly.
# Run: sudo salt-call --local state.apply cachyos
# Verify only: sudo salt-call --local state.apply cachyos test=True

# ===================================================================
# Files that must exist
# ===================================================================

{% for name, path in checks.required_files.items() %}
cachyos_{{ name }}:
  file.exists:
    - name: {{ path | replace('${USER}', user) }}
{% endfor %}

# ===================================================================
# Configuration & content verification checks
# ===================================================================

{% for name, check in checks.verify_checks.items() %}
cachyos_{{ name }}:
  cmd.run:
    - name: 'true'
    - unless: '{{ check | replace("${USER}", user) | replace("${TIMEZONE}", host.timezone) | replace("${LOCALE}", host.locale) | replace("${HOSTNAME}", host.hostname) | replace("'", "''") }}'
{% endfor %}

# ===================================================================
# Services that must be enabled
# ===================================================================

{% for id_suffix, svc in checks.enabled_services.items() %}
cachyos_svc_{{ id_suffix }}:
  service.enabled:
    - name: {{ svc }}
{% endfor %}

# ===================================================================
# Package spot-checks (representative set from each category)
# ===================================================================

{% for category, packages in checks.package_checks.items() %}
{% for pkg in packages %}
cachyos_{{ category }}_{{ pkg | replace('-', '_') }}:
  cmd.run:
    - name: 'true'
    - unless: pacman -Q {{ pkg }} >/dev/null 2>&1
{% endfor %}
{% endfor %}
