{% from '_imports.jinja' import host %}
# opencode.sls — legacy entry point.
# ProxyPilot config + container deployment moved to proxypilot.sls.
# This file exists solely to preserve the `host.features.opencode` feature gate.

include:
  - proxypilot
