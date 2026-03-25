# Quickstart: Sysusers and Tmpfiles Adoption

## Goal

Verify that the repository can migrate representative long-lived services to declarative identity and managed-path policies without breaking repeatable Salt applies or expected service startup behavior.

## Prerequisites

- Work on branch `074-sysusers-tmpfiles-adoption`
- Representative in-scope services selected for the first migration slice
- A test machine or VM where service identities and managed paths can be removed and recreated safely

## Implementation Workflow

1. Inventory the first migration slice.
   - Confirm the phase-1 entries in `states/data/managed_resources.yaml`.
   - Record which of those entries are representative identity, persistent-path, and ephemeral-path cases.
2. Replace bespoke identity provisioning with the shared declarative identity pattern.
   - Render service accounts through `states/systemd_resources.sls` and `states/configs/managed-service-accounts.conf.j2`.
   - Remove per-service direct account creation logic for migrated services while keeping account names and path roots unchanged.
3. Replace bespoke path setup with the shared managed-path pattern.
   - Render tmpfiles rules through `states/systemd_resources.sls` and `states/configs/managed-service-paths.conf.j2`.
   - Keep helper-script scratch directories out of scope.
4. Update representative service states to depend on `managed_service_accounts_ensure` and `managed_service_paths_ensure` rather than legacy setup helpers.
5. Add or update verification coverage for the migrated patterns in `tests/test_render_contracts.py`.

## Validation Workflow

1. Run repository validation.

```bash
just validate
just lint
```

2. Run targeted tests if helper rendering or inventory logic changes.

```bash
pytest tests/ -q
```

3. Verify identity recreation for representative migrated services.
   - Remove or simulate absence of a representative migrated service identity.
   - Apply the repository workflow once.
   - Confirm the identity exists and a second apply does not fail.

4. Verify persistent path recreation.
   - Remove a representative persistent managed path.
   - Apply the repository workflow once.
   - Confirm the path returns with the expected owner, group, and mode.

5. Verify ephemeral path lifecycle.
   - Remove a representative ephemeral managed path or reboot the test environment.
   - Trigger the relevant recreation path.
   - Confirm the path exists before the migrated service expects to use it.

6. Verify service operability.
   - Start or restart representative migrated services.
   - Confirm they still use the same service-visible paths and do not fail due to missing identities or managed paths.

## Expected Outcome

- Representative migrated services no longer rely on bespoke account creation helpers or ad-hoc tmpfiles handling.
- Repeated applies stay clean on compliant machines.
- Missing representative identities and managed paths are restored in one run.
- Maintainers can add future services using one documented identity/path pattern.
