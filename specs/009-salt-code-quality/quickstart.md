# Quickstart: Salt Code Quality Improvement

**Branch**: `009-salt-code-quality` | **Date**: 2026-03-09

## Prerequisites

- CachyOS workstation with Salt masterless (`salt-call --local`)
- Python 3.12+ with `jinja2` and `pyyaml` (already installed for existing lint scripts)
- Access to `just` command for validation

## Validation Workflow

```bash
# 1. Run lint checks (existing + new idempotency check)
python3 scripts/lint-jinja.py

# 2. Render Salt states to verify no regressions
just

# 3. Full apply (on the live system)
sudo salt-call --local state.apply

# 4. Second apply — should report zero changes
sudo salt-call --local state.apply
```

## Key Files Modified

| File | Change |
|------|--------|
| `scripts/lint-jinja.py` | Add idempotency guard check + inline suppression support |
| `states/_macros_pkg.jinja` | Add `version` param to `npm_pkg` and `paru_install` |
| `states/_macros_service.jinja` | Add `user_service_with_unit()` combined macro |
| `states/installers.sls` | Split mpv scripts to `installers_mpv.sls` |
| `states/services.sls` | Split Bitcoind to `services_bitcoind.sls` |
| `states/monitoring.sls` | Split Loki stack to `monitoring_loki.sls` |
| `states/data/desktop.yaml` | New — Hyprland ecosystem packages |
| `states/desktop.sls` | Use `import_yaml` for package lists |
| `states/system_description.sls` | Update include list for split files |
| Multiple `.sls` files | Add missing idempotency guards, retry, parallel, requisites |

## Testing a Single Change

To test a specific state file after modification:

```bash
# Render check (no system changes)
just

# Apply only one state
sudo salt-call --local state.sls <state_name>

# Verify idempotency
sudo salt-call --local state.sls <state_name>
```

## Adding a Lint Suppression

For states that intentionally skip a guard (e.g., `sysctl --system` triggered by `onchanges`):

```yaml
# salt-lint: disable=idempotency
sysctl_apply:
  cmd.run:
    - name: sysctl --system
    - onchanges:
      - file: sysctl_config
```
