# Feature Specification: Salt Code Quality Improvement

**Feature Branch**: `009-salt-code-quality`
**Created**: 2026-03-09
**Status**: Draft
**Input**: User description: "Radically improve Salt code quality following best practices for performance, maintainability, and reliability"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consistent Idempotency Across All States (Priority: P1)

As the system operator, I want every Salt state to be fully idempotent so that running `salt-call --local state.apply` multiple times produces zero unnecessary changes and completes faster on subsequent runs.

**Why this priority**: Idempotency is the foundation of declarative configuration management. Without it, every apply is slow, unpredictable, and produces noisy output that masks real changes. This is the single highest-impact improvement.

**Independent Test**: Run `salt-call --local state.apply` twice in succession; the second run should report zero changes for all states that were already applied.

**Acceptance Scenarios**:

1. **Given** a fully applied system, **When** `salt-call --local state.apply` runs again, **Then** every `cmd.run`/`cmd.script` state reports "already satisfied" via `creates:`, `unless:`, or `onlyif:` guards.
2. **Given** a new `cmd.run` state is added to the codebase, **When** it lacks an idempotency guard, **Then** a lint check flags the missing guard before merge.
3. **Given** a network download state, **When** the target file already exists at the expected version, **Then** the state skips execution entirely.

---

### User Story 2 - Network Resilience on All Remote Operations (Priority: P1)

As the system operator, I want all states that access the network to have retry logic and (where safe) parallel execution, so that transient network failures don't break the full apply and independent downloads run concurrently.

**Why this priority**: Network operations are the most common source of apply failures. Retry and parallelism together reduce both failure rate and total apply time — directly addressing the "faster and better" goal.

**Independent Test**: Simulate a transient network failure (e.g., temporary DNS block) during apply; states should retry and eventually succeed without manual intervention.

**Acceptance Scenarios**:

1. **Given** a network-dependent state (curl, cargo, pip, npm, paru, pacman, git clone), **When** the first attempt fails with a transient error, **Then** the state retries up to `retry_attempts` times at `retry_interval` spacing.
2. **Given** multiple independent download/install states, **When** they have no dependency chain between them, **Then** they execute in parallel.
3. **Given** a state with an explicit `require` chain to another install, **When** it runs, **Then** it does NOT use `parallel: True`.

---

### User Story 3 - Consolidated Macro Library (Priority: P2)

As a codebase maintainer, I want repeated patterns (health-check polling, user service deploy+enable, one-shot migrations) to be abstracted into reusable macros, so that adding new services or migrations requires minimal boilerplate and follows consistent conventions.

**Why this priority**: Duplicate patterns are the primary source of inconsistency and bugs. Consolidating them into tested macros reduces the surface area for errors and makes the codebase easier to extend.

**Independent Test**: Identify a state that manually reimplements a pattern already covered by a macro; refactor it to use the macro and verify the apply produces identical results.

**Acceptance Scenarios**:

1. **Given** a state that manually polls a health-check endpoint, **When** refactored to use `service_with_healthcheck`, **Then** behavior is identical and code is shorter.
2. **Given** a new user service to deploy, **When** the maintainer uses a single macro call, **Then** the unit file is deployed, daemon-reload fires, and the service is enabled — without manually chaining three separate states.
3. **Given** macro parameters like `version`, **When** macros like `npm_pkg` and `paru_install` are called, **Then** they support version tracking for idempotency.

---

### User Story 4 - Data-Driven Configuration (Priority: P2)

As a codebase maintainer, I want hardcoded package lists, directory paths, and service parameters to live in `data/*.yaml` files, so that adding or changing a package/service requires editing only a data file — not Salt state logic.

**Why this priority**: Data-driven design separates "what to install" from "how to install it", making changes safer (no risk of breaking Jinja logic) and enabling tooling like `pkg-drift.zsh` to validate declarations against system state.

**Independent Test**: Move a hardcoded package list from a `.sls` file to a `data/*.yaml` file; verify the apply produces identical results.

**Acceptance Scenarios**:

1. **Given** a package list currently hardcoded in a `.sls` file, **When** it is moved to `data/*.yaml` and loaded via `import_yaml`, **Then** the state installs exactly the same packages.
2. **Given** a new package to add, **When** the maintainer edits only `data/*.yaml`, **Then** the next apply installs it without touching any `.sls` file.
3. **Given** service-specific directories or paths, **When** they are defined in data files, **Then** states reference them via Jinja variables instead of string literals.

---

### User Story 5 - Explicit Dependency Chains (Priority: P2)

As the system operator, I want all states to have explicit `require`/`watch`/`onchanges` requisites so that states never fail due to missing prerequisites and the apply order is deterministic.

**Why this priority**: Implicit ordering (relying on state ID alphabetical order or file position) is fragile. Explicit requisites make the dependency graph visible, debuggable, and resilient to refactoring.

**Independent Test**: Reorder states within a file; verify the apply still succeeds because requisites enforce correct ordering.

**Acceptance Scenarios**:

1. **Given** a service state that depends on a config file, **When** the config file state is moved to a different position in the file, **Then** the service state still runs after the config file is deployed.
2. **Given** a model pull state that depends on a running service, **When** the service health check times out, **Then** the model pull state is skipped (not attempted).
3. **Given** a mount state, **When** it runs, **Then** it explicitly requires the directory creation state, not just implicit ordering.

---

### User Story 6 - Modular State Files (Priority: P3)

As a codebase maintainer, I want large monolithic state files to be split into focused, single-responsibility modules, so that each file is easy to understand, test independently, and modify without risk of side effects.

**Why this priority**: Smaller files are easier to review, debug, and parallelize. This is a quality-of-life improvement that compounds over time as the codebase grows.

**Independent Test**: Split a large state file into two or more focused files; verify the apply produces identical results and the `system_description.sls` include list is updated.

**Acceptance Scenarios**:

1. **Given** `installers.sls` (150+ lines mixing 6+ install types), **When** split into focused modules, **Then** each module handles one concern and can be included/excluded independently.
2. **Given** `services.sls` with mixed simple and complex services, **When** split, **Then** simple services (pacman + enable) are separate from complex ones (custom builds, ACLs).
3. **Given** a split state file, **When** `system_description.sls` includes the new modules, **Then** the full apply produces identical system state.

---

### User Story 7 - Automated Lint Checks (Priority: P3)

As a codebase maintainer, I want automated lint checks that catch common Salt anti-patterns before they reach the main branch, so that code quality is enforced consistently without manual review burden.

**Why this priority**: Lint checks prevent regressions. Without them, every improvement made in this feature could be undone by future changes. This is the sustainability layer.

**Independent Test**: Introduce a deliberate anti-pattern (e.g., `cmd.run` without guard); verify the lint script catches it.

**Acceptance Scenarios**:

1. **Given** a `cmd.run` state without `creates:`, `unless:`, or `onlyif:`, **When** the lint script runs, **Then** it reports the missing guard with file and line number.
2. **Given** a network-dependent state without `retry:`, **When** the lint script runs, **Then** it reports the missing retry directive.
3. **Given** all existing state files, **When** the lint script runs after all fixes are applied, **Then** zero violations are reported.

---

### Edge Cases

- What happens when a macro is refactored but downstream states still use old parameter signatures? All macro callers must be updated atomically, and new parameters must have defaults for backward compatibility.
- What happens when a data file has a typo in a package name? The pacman/paru state should fail clearly with the invalid package name, not silently skip it.
- What happens when splitting a state file creates circular dependencies between the new modules? State files must form a DAG; circular requires are a Salt error and must be detected during review.
- What happens when a lint rule produces false positives on intentionally unguarded states (e.g., `sysctl --system` triggered by `onchanges`)? The lint script must support inline suppression comments (e.g., `# salt-lint: disable=idempotency`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every `cmd.run` and `cmd.script` state MUST have at least one idempotency guard (`creates:`, `unless:`, `onlyif:`, or `onchanges:`).
- **FR-002**: Every state that performs a network operation (download, install from remote, git clone) MUST have `retry: {attempts: retry_attempts, interval: retry_interval}`.
- **FR-003**: Independent network operations (no `require` chain between them) MUST use `parallel: True`, with a global Salt concurrency limit to prevent resource exhaustion during heavy builds (cargo, paru/makepkg, PKGBUILD).
- **FR-004**: Repeated patterns (health-check polling, user service deploy+enable, file deploy+daemon-reload) MUST be consolidated into parameterized macros in `_macros_*.jinja`.
- **FR-005**: Macro `npm_pkg` MUST accept an optional `version` parameter for idempotent version-tracked installs.
- **FR-006**: Macro `paru_install` MUST support version tracking via version stamp files, consistent with other install macros.
- **FR-007**: Hardcoded package lists in generic/multi-purpose `.sls` files MUST be extracted to `data/*.yaml` files and loaded via `import_yaml`. Domain-specific state files (e.g., `audio.sls`, `steam.sls`, `dns.sls`) MAY keep inline package lists if they contain ≤10 packages and the list is the state's core logic.
- **FR-008**: All states with dependencies MUST use explicit `require:`, `watch:`, or `onchanges:` requisites instead of relying on implicit ordering.
- **FR-009**: State files exceeding 120 lines or covering 3+ unrelated concerns MUST be split into focused single-responsibility modules.
- **FR-010**: A lint script MUST exist at `scripts/lint-salt.py` that checks for: missing idempotency guards, missing retry on network states, and inconsistent state ID naming.
- **FR-011**: The lint script MUST support inline suppression comments for intentional exceptions.
- **FR-012**: State ID naming MUST follow the `target_descriptor` pattern consistently (e.g., `loki_config`, `greetd_enabled`), with `install_*` and `build_*` reserved for macro-generated IDs.
- **FR-013**: All macro changes MUST be backward-compatible — existing callers MUST continue to work without modification (new parameters use defaults).
- **FR-014**: The `system_description.sls` include list MUST be updated to reflect any state file splits.

### Key Entities

- **State File**: A `.sls` file in `states/` that declares system configuration. Key attributes: include list, state IDs, requisites, idempotency guards.
- **Macro**: A reusable Jinja template in `_macros_*.jinja` that generates one or more Salt states from parameters. Key attributes: parameters, defaults, generated state IDs.
- **Data File**: A YAML file in `data/` that declares configuration values consumed by states via `import_yaml`. Key attributes: categories, package names, versions, paths.
- **Lint Rule**: A check in `scripts/lint-salt.py` that validates a Salt best practice. Key attributes: rule ID, pattern match, error message, suppression mechanism.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A second consecutive `salt-call --local state.apply` on a fully-applied system reports zero changes across all states.
- **SC-002**: Total apply time for a fully-applied system (no-change run) is reduced by at least 30% compared to baseline, measured by `salt-call` wall-clock time.
- **SC-003**: The lint script reports zero violations when run against the complete state tree after all improvements are applied.
- **SC-004**: No state file exceeds 120 lines or covers more than 2 unrelated concerns.
- **SC-005**: At least 80% of package declarations live in `data/*.yaml` files rather than inline in `.sls` files.
- **SC-006**: Every network-dependent state has both retry logic and (where applicable) parallel execution, verified by lint script.
- **SC-007**: Adding a new system package requires editing only `data/packages.yaml` — no `.sls` file changes needed.

## Clarifications

### Session 2026-03-09

- Q: Should ALL inline package lists be extracted to data files, or only lists in generic multi-purpose states? → A: Option B — extract only lists in generic/multi-purpose states; domain-specific states keep inline lists if ≤10 packages.
- Q: Should `parallel: True` apply to all independent network ops or exclude heavy builds? → A: Option C — apply parallel to everything but add a global Salt concurrency limit to prevent resource exhaustion.

## Assumptions

- The existing macro library (`_macros_*.jinja`) is stable and well-tested; changes will be additive (new parameters with defaults), not breaking.
- `salt-call --local state.apply` is the primary execution model (masterless Salt); no Salt master considerations.
- The `just` command (default target `system_description`) is the standard way to validate Salt rendering and catch regressions.
- Python 3.12+ is available for lint scripts (consistent with existing `scripts/lint-docs.py` and `scripts/lint-ownership.py`).
- State file splits will maintain identical system state — no functional changes, only organizational improvements.
- The `retry_attempts` (3) and `retry_interval` (10) constants from `_macros_common.jinja` are the standard values for all retry logic.
