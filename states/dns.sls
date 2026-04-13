{% from '_imports.jinja' import host %}
{% set dns = host.features.dns %}

# DNS services migrated to data-driven definitions in services.yaml.
# The orchestrator loop in services.sls handles unbound, adguardhome, and avahi
# gated by features.dns.* flags.

# Reusable restart target for external configs (e.g. tailscale DNS stub)
# that drop files into unbound.conf.d/ and need unbound to pick them up.
{% if dns.unbound %}
unbound_restart_or_reload:
  cmd.run:
    - name: unbound-control reload 2>/dev/null || systemctl restart unbound 2>/dev/null || true
{% endif %}
