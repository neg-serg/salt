# Research: Sysusers and Tmpfiles Adoption

## Decision 1: Limit the first migration slice to long-lived managed services

- Decision: Migrate only repository-managed long-lived services and their stable service paths in the first phase.
- Rationale: The spec is about replacing bespoke service identity and filesystem setup. Helper scripts, temporary build directories, and test scaffolding use different lifecycles and would blur the migration boundary without improving service operability.
- Alternatives considered:
  - Migrate every `mkdir -p` occurrence in the repo: rejected because many of those paths are one-shot execution scratch space, not managed service resources.
  - Migrate only one showcase service: rejected because it would not establish a repository-wide pattern or satisfy the onboarding goals.

## Decision 2: Replace `system_daemon_user` with declarative identity definitions rendered into `sysusers.d`

- Decision: Move dedicated service-account ownership from direct `user.present` usage toward a shared declaration pattern that renders system identity policy files.
- Rationale: Current `system_daemon_user` consolidates repeated Salt logic, but it still manages service identities imperatively inside individual states. A declarative identity definition better matches the feature goal and reduces duplicate-account edge cases across services.
- Alternatives considered:
  - Keep `system_daemon_user` unchanged and only document it better: rejected because it does not adopt the new system policy mechanism the feature is targeting.
  - Replace every service with `DynamicUser=yes`: rejected because some services need stable ownership over persistent paths and existing data locations.

## Decision 3: Represent managed paths as explicit tmpfiles-backed rules

- Decision: Describe persistent and ephemeral service paths through explicit managed path rules that render into tmpfiles policy fragments.
- Rationale: The repository already has isolated tmpfiles usage for MPD and multiple services with manually managed directories. A shared rule format gives one place to express type, owner, group, mode, and lifecycle expectations for directories, FIFOs, and similar resources.
- Alternatives considered:
  - Leave persistent directories on `file.directory` and use tmpfiles only for ephemeral resources: rejected because the maintainer story needs one coherent pattern.
  - Encode path rules directly inside unit files only: rejected because several services depend on paths outside what unit-level runtime directives alone cover.

## Decision 4: Keep service-visible locations stable during migration

- Decision: Preserve existing service names, path locations, and ownership expectations while changing only how those resources are declared and materialized.
- Rationale: The feature's value is consistency and repeatability, not moving data or renaming resources. Changing locations would expand the blast radius and make regressions harder to isolate.
- Alternatives considered:
  - Relocate service state under new standardized prefixes during the same migration: rejected because that turns a policy migration into a data-layout migration.
  - Rename service accounts for consistency: rejected because it would require unnecessary service-unit and file-ownership churn.

## Decision 5: Validate with representative migrated services rather than every service at once

- Decision: Define a first migration set of representative services covering dedicated system users, persistent state directories, and tmpfiles-managed ephemeral resources.
- Rationale: The repository already shows candidate patterns in Loki, AdGuardHome, Bitcoind, and MPD. Covering these shapes provides confidence in the policy without forcing a repo-wide flag day.
- Alternatives considered:
  - Convert every eligible service in one change: rejected because the plan phase should establish sequencing and verification before a broad migration.
  - Avoid representative validation and rely only on render/lint checks: rejected because the feature explicitly depends on service lifecycle behavior.

## Implementation Note: Use one shared systemd resource state

- Decision: Centralize the rendered `sysusers.d` and `tmpfiles.d` fragments in `states/systemd_resources.sls`, backed by `states/data/managed_resources.yaml`.
- Rationale: One shared orchestration state keeps the repository's service-domain states small and lets representative services depend on the same ensure/apply entry points.
- Alternatives considered:
  - Give every service its own rendered `sysusers.d` and `tmpfiles.d` file: rejected because it would recreate per-service sprawl with a different mechanism.
  - Keep the inventory inline inside the state file: rejected because maintainers would lose the data-driven overview of the migration slice.
