# Feature Specification: Salt Package Management with Minimal Dependency Coverage

**Feature Branch**: `008-salt-pkg-management`
**Created**: 2026-03-09
**Status**: Draft
**Input**: User description: "Нужно составить минимальный список пакетов, который благодаря зависимостям создаст полное покрытие текущего набора. Salt должен управлять установкой программ."

## Clarifications

### Session 2026-03-09

- Q: Does "minimal set" mean `pacman -Qqe` as-is or a computed transitive reduction? → A: Start with `pacman -Qqe` baseline, then offer optional reduction pass presenting candidates for human review.
- Q: Should packages in existing state files (audio.sls, steam.sls, etc.) be consolidated into the central file or coexist? → A: Coexist — central data file covers packages not already managed by domain-specific states; individual states retain their own package installs.
- Q: Single data file with categories vs multiple files per category? → A: Single file (`states/data/packages.yaml`) with YAML keys per category (e.g., `base:`, `desktop:`, `dev:`). Consistent with existing `states/data/` pattern of one YAML per concern.
- Q: Should Salt ever remove packages not in the declared list? → A: Report-only. Drift detection lists unmanaged packages; admin removes manually via pacman. Salt never auto-removes packages.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture Current Package State as Minimal Explicit Set (Priority: P1)

The administrator runs a one-time analysis tool that examines all currently installed packages on the system and produces an explicit package list. The baseline is `pacman -Qqe` (all packages marked as explicitly installed). An optional reduction pass then identifies packages in the explicit list that are already transitive dependencies of other explicit packages, presenting them as candidates for removal — subject to human review before any changes. The output is a structured data file that Salt can consume.

**Why this priority**: Without the initial capture of the current system state, no other stories can proceed. This is the foundation — converting the implicit "whatever is installed" into an explicit, version-controlled declaration.

**Independent Test**: Run the analysis tool on the live system. Verify that installing only the packages in the output list (on a clean system or container) would produce the full package set via dependency resolution.

**Acceptance Scenarios**:

1. **Given** a running CachyOS system with ~1000+ installed packages, **When** the analysis tool runs, **Then** it produces a structured data file listing only explicitly-needed packages (not their transitive dependencies), grouped by logical category.
2. **Given** the generated package list, **When** compared against `pacman -Qqe` (explicitly installed), **Then** the baseline list matches exactly. After the optional reduction pass, removed candidates are only those confirmed as transitive dependencies of other listed packages.
3. **Given** the generated package list, **When** a package is already managed by an existing Salt state (e.g., via `pacman_install` or `paru_install` macro), **Then** it is flagged or excluded from the general list to avoid duplication.

---

### User Story 2 - Declarative Package Management via Salt (Priority: P1)

Salt states consume the minimal package list and ensure all listed packages are installed on every apply. New packages are added by editing the data file; removed packages are flagged for review. The existing macro system (`pacman_install`, `paru_install`) is extended or complemented to handle bulk package declarations from the data file.

**Why this priority**: This is the core value — moving from "packages are managed outside Salt" to "Salt is the single source of truth for what's installed." Equal priority with Story 1 because neither delivers value alone.

**Independent Test**: Add a test package to the data file, run `salt-call state.apply`, verify it gets installed. Remove it, run again, verify a warning or removal action occurs.

**Acceptance Scenarios**:

1. **Given** the minimal package list in a Salt-consumable data file, **When** `salt-call state.apply` runs, **Then** all listed packages are installed (idempotently — no action if already present).
2. **Given** a new package added to the data file, **When** Salt applies, **Then** the package is installed along with its dependencies.
3. **Given** a package removed from the data file, **When** Salt applies, **Then** the system reports the discrepancy (does not auto-remove without explicit confirmation to avoid breaking the system).
4. **Given** AUR packages in the list, **When** Salt applies, **Then** AUR packages are installed via `paru` while official repo packages use `pacman`.

---

### User Story 3 - Categorized Package Organization (Priority: P2)

Packages in the data file are organized into logical groups (e.g., "base-system", "desktop", "development", "audio", "networking", "gaming") matching the existing Salt state module structure. This allows selective installation of package groups and makes the list human-readable and maintainable.

**Why this priority**: Organization improves maintainability but isn't strictly required for the system to work. The flat list from Story 1 is functional on its own.

**Independent Test**: Verify that the data file has clear category boundaries, that each category can be installed independently, and that the union of all categories equals the full package set.

**Acceptance Scenarios**:

1. **Given** the package data file, **When** an administrator reads it, **Then** packages are grouped under named categories that align with existing Salt state modules (audio, desktop, steam, etc.).
2. **Given** a category in the data file, **When** Salt applies only that category's state, **Then** only packages in that group (plus their dependencies) are installed.

---

### User Story 4 - Package Drift Detection (Priority: P3)

A periodic or on-demand check compares the actual installed packages against the declared minimal set. Any packages installed manually (not in the list and not a dependency of a listed package) are reported as "drift." Any listed packages not present on the system are reported as "missing."

**Why this priority**: Drift detection is a maintenance convenience — the system works without it, but it prevents silent divergence over time.

**Independent Test**: Manually install a package not in the list, run the drift check, verify it's reported. Remove a listed package, run the check, verify it's flagged as missing.

**Acceptance Scenarios**:

1. **Given** a system where all declared packages are installed, **When** drift detection runs, **Then** it reports no drift.
2. **Given** a manually installed package not in the declared list, **When** drift detection runs, **Then** it reports the package as unmanaged/drifted.
3. **Given** a declared package that was manually removed, **When** drift detection runs, **Then** it reports the package as missing.

---

### Edge Cases

- What happens when a package in the minimal list is removed from the Arch/AUR repositories? Salt should report the failure clearly but continue installing other packages.
- What happens when a dependency of a listed package changes upstream (e.g., package A no longer depends on B)? The orphaned package B should be detected by drift detection or `pacman -Qdtq`.
- What happens when two categories list the same package? Deduplication must occur — the package is installed once regardless of how many categories reference it.
- What happens when a listed AUR package has a conflicting official repo version? The data file must clearly mark packages as `aur` vs `official` to avoid ambiguity.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an analysis tool that captures the explicit package set (`pacman -Qqe`) as a baseline, with an optional reduction pass that identifies packages already covered as transitive dependencies of other explicit packages — presenting reduction candidates for human review.
- **FR-002**: The analysis tool MUST output a single structured, human-editable YAML file (`states/data/packages.yaml`) with category keys, consumable by Salt states via `import_yaml`.
- **FR-003**: The analysis tool MUST distinguish between official repository packages and AUR packages.
- **FR-004**: Salt states MUST install all packages declared in the data file idempotently (no re-install if already present).
- **FR-005**: Salt states MUST use `pacman` for official packages and `paru` for AUR packages.
- **FR-006**: The data file MUST support logical grouping/categorization of packages.
- **FR-007**: Salt MUST report (not silently auto-remove) packages that were removed from the data file but remain installed.
- **FR-008**: The system MUST integrate with existing Salt macro infrastructure (`_macros_pkg.jinja`) rather than duplicating package management logic.
- **FR-009**: Packages already managed by specific Salt state modules (e.g., `audio.sls`, `steam.sls`) MUST NOT be duplicated in the general package list — the analysis tool must cross-reference existing states.
- **FR-010**: The system MUST handle network failures gracefully with retry logic consistent with existing Salt conventions (3 attempts, 10s interval).
- **FR-011**: A drift detection mechanism MUST compare declared packages against actual system state and report discrepancies.

### Key Entities

- **Package Declaration**: A named package with its source (official/AUR) and category. The minimal unit of the data file. (No version pinning — pacman resolves versions from repos.)
- **Package Category**: A logical grouping of packages (e.g., "desktop", "audio", "development") that maps to Salt state modules or functional areas.
- **System Snapshot**: The output of the analysis tool — a point-in-time capture of the minimal explicit package set, stored as a versioned data file.
- **Drift Report**: The output of drift detection — lists of unmanaged, missing, and orphaned packages compared against the declared state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The declared package list contains fewer entries than `pacman -Qqe` output (minimal set is smaller than or equal to the full explicit list, with dependency-satisfied packages removed where possible).
- **SC-002**: A fresh system provisioned using only the Salt-managed package list plus dependency resolution results in a functionally equivalent system (all user-facing tools and services available).
- **SC-003**: Adding or removing a package from the data file takes under 1 minute of human effort (edit one line in one file).
- **SC-004**: Salt apply completes package management within the existing apply time budget (no more than 2x increase over current apply duration when all packages are already installed).
- **SC-005**: 100% of explicitly-installed packages on the system are accounted for — either in the minimal package list or in a specific Salt state module.
- **SC-006**: Drift detection identifies unmanaged packages within one run cycle after they are installed outside Salt.

## Assumptions

- The system uses pacman and paru as its sole package managers (no Flatpak/Snap for this scope — Flatpak is handled separately in `flatpak.sls`).
- The current set of installed packages is considered the "golden state" — the analysis tool captures what exists, not what should exist.
- Package version pinning is NOT in scope for the initial implementation. The list declares package names; pacman resolves versions from repos.
- The analysis tool runs locally on the target machine (not remotely via Salt master) since this is a masterless Salt setup.
- Existing `pacman_install`/`paru_install` calls in individual state files remain authoritative for their specific packages — the general package list is for everything else. The analysis tool must exclude packages already managed by domain-specific states to avoid duplication. The two systems coexist: domain states own domain packages, the central file owns the rest.
- The CLAUDE.md rule "Packages installed via pacman/paru outside Salt" will be updated to reflect that Salt now manages package installation.
