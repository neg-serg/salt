# Feature Specification: Domain Package Separation

**Feature Branch**: `055-domain-pkg-separation`
**Created**: 2026-03-20
**Status**: Draft
**Input**: User description: "Разделить 'пакеты' и 'фичи' более строго. В states/packages.sls есть категории audio, fonts, gaming, хотя эти домены уже имеют собственные states. Это повышает риск двойной ответственности и размывает границы. Оставить в packages.sls только truly base/system/dev пакеты, а доменные наборы держать строго в своих *.sls плюс в host.features.*."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Trace Any Package to Its Owning Domain (Priority: P1)

As a system maintainer, when I see a package installed on my system, I can trace it back to exactly one Salt state that is responsible for it. There is no ambiguity about whether a package comes from `packages.sls` (infrastructure layer) or a domain state (e.g., `audio.sls`, `steam.sls`).

**Why this priority**: This is the core value — eliminating dual ownership. Without clear single-ownership, adding/removing packages risks silent conflicts (e.g., removing a package from `packages.yaml` while a domain state still expects it, or vice versa).

**Independent Test**: Run `just validate` and `just apply` — no package should appear in both `packages.yaml` and a domain state's package list. A lint check can verify zero overlap.

**Acceptance Scenarios**:

1. **Given** a fresh apply, **When** I search for any package name across `states/data/packages.yaml` and all `*.sls` files, **Then** that package appears in exactly one location (either `packages.yaml` or a domain state, never both).
2. **Given** the `audio` category previously existed in `packages.yaml`, **When** I look at `packages.yaml` after migration, **Then** there is no `audio` category — all audio packages are declared in `audio.sls` (or its data file).
3. **Given** a domain state like `steam.sls` manages gaming packages, **When** I look at `packages.yaml`, **Then** there is no `gaming` category.

---

### User Story 2 - Packages.sls Contains Only Infrastructure Packages (Priority: P1)

As a maintainer, `packages.sls` is the "foundation layer" — it installs only packages that are universally needed (base system, development tools, system utilities, networking) regardless of which domain features are enabled. Domain-specific packages live in their respective states.

**Why this priority**: Equal to P1 because this defines the boundary rule that all other stories depend on.

**Independent Test**: Review `packages.yaml` categories — only `base`, `dev`, `network`, `system`, `media`, `other`, and `aur` remain. Categories like `audio`, `fonts`, `desktop`, `gaming` are removed.

**Acceptance Scenarios**:

1. **Given** the current `packages.yaml` has categories `audio`, `fonts`, `gaming`, `desktop`, **When** migration is complete, **Then** those categories no longer exist in `packages.yaml`.
2. **Given** `packages.sls` iterates over categories, **When** I read the category list in `packages.sls`, **Then** it only contains infrastructure categories (`base`, `dev`, `network`, `system`, `media`, `other`).
3. **Given** a package like `pipewire` was in `packages.yaml:audio`, **When** I check after migration, **Then** it is declared in `audio.sls` (or `data/audio.yaml`) with proper inline comments.

---

### User Story 3 - Domain States Are Self-Contained (Priority: P2)

Each domain state (`audio.sls`, `fonts.sls`, `steam.sls`, `desktop.sls`) declares all the packages it needs — either inline or via its own data file. A domain state does not depend on `packages.sls` having pre-installed any domain-specific package.

**Why this priority**: This enables independent feature toggling — disabling `host.features.steam` should cleanly remove all gaming packages without leftover orphans from `packages.yaml`.

**Independent Test**: Disable a feature flag (e.g., `host.features.steam: false`), run `just validate` — no errors about missing packages that were previously in `packages.yaml`.

**Acceptance Scenarios**:

1. **Given** `host.features.steam` is `false`, **When** Salt renders the state tree, **Then** no gaming-related packages are included in any state.
2. **Given** `audio.sls` previously relied on `packages.yaml:audio` for `pipewire`, **When** `audio.sls` is rendered independently, **Then** it declares `pipewire` in its own package list.
3. **Given** a domain state has packages, **When** I read the state or its data file, **Then** every package has an inline comment describing what it is (per project convention).

---

### User Story 4 - The `other` and `aur` Categories Are Audited (Priority: P3)

The catch-all `other` and `aur` categories in `packages.yaml` are audited for packages that belong to a specific domain. Domain-specific packages are relocated to their owning state.

**Why this priority**: Lower priority because `other`/`aur` are explicitly catch-all — some packages genuinely don't belong to any domain. This is a cleanup pass, not a structural change.

**Independent Test**: Review each package in `other` and `aur` — if it's only needed when a specific feature flag is enabled, it should move to that domain state.

**Acceptance Scenarios**:

1. **Given** a package in `other` like `telegram-desktop`, **When** I assess its domain, **Then** it stays in `other` because it's a general desktop app not gated by a feature flag.
2. **Given** a package in `aur` that is only used by a specific domain state, **When** migration is complete, **Then** it moves to that domain state's package list.

---

### Edge Cases

- What happens when a package is genuinely shared between two domains (e.g., `ffmpeg` used by both `media` and `audio`)? — It stays in `packages.yaml` (infrastructure layer) since it's not domain-exclusive.
- What happens when a domain state is disabled via feature flag but its packages were previously in `packages.yaml`? — Packages are no longer installed (correct behavior — the domain owns them now).
- What if a domain state's data file doesn't exist yet (e.g., no `data/audio.yaml`)? — Packages can be declared inline in the `.sls` file or a new data file is created, following the existing pattern (e.g., `data/fonts.yaml`).
- What about packages in `desktop` category that belong to Hyprland/desktop environment? — `desktop.sls` already manages its own packages via `data/desktop.yaml`; the `desktop` category in `packages.yaml` is removed and any truly generic desktop packages (if any) move to `other`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The `packages.yaml` file MUST contain only infrastructure categories: `base`, `dev`, `network`, `system`, `media`, `other`, and `aur`.
- **FR-002**: Domain-specific categories (`audio`, `fonts`, `gaming`, `desktop`) MUST be removed from `packages.yaml`.
- **FR-003**: Each package removed from `packages.yaml` MUST be relocated to the appropriate domain state or its data file, preserving inline description comments.
- **FR-004**: The `packages.sls` category iteration loop MUST be updated to exclude removed categories.
- **FR-005**: No package MUST appear in both `packages.yaml` and a domain state's package list (zero overlap rule).
- **FR-006**: Domain states MUST be self-contained — they declare all packages they need without depending on `packages.yaml` for domain-specific packages.
- **FR-007**: Every relocated package MUST retain or receive an inline YAML comment describing what it is.
- **FR-008**: The `other` and `aur` categories MUST be audited for domain-specific packages that should be relocated to their owning state.
- **FR-009**: A lint check MUST exist to verify the zero-overlap rule (no package appears in both `packages.yaml` and any domain state's data/inline package list).
- **FR-010**: `just validate` and `just apply` MUST succeed after all changes with no regressions.

### Key Entities

- **Infrastructure Package**: A package needed universally regardless of enabled features (lives in `packages.yaml`).
- **Domain Package**: A package specific to a feature domain like audio, gaming, or fonts (lives in the domain's `.sls` or data file).
- **Category**: A top-level key in `packages.yaml` that groups related packages.
- **Domain State**: A Salt state file (`.sls`) that owns a feature domain end-to-end (packages + configuration + services).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero packages appear in both `packages.yaml` and any domain state — verified by automated lint check.
- **SC-002**: `packages.yaml` contains at most 7 categories (`base`, `dev`, `network`, `system`, `media`, `other`, `aur`) — down from current 11.
- **SC-003**: `just validate` passes with zero errors after migration.
- **SC-004**: `just apply` completes successfully with no package-related failures.
- **SC-005**: Each domain state can be independently disabled via its feature flag without leaving orphan packages from `packages.yaml`.
- **SC-006**: 100% of packages in the system have exactly one declaration point with an inline description comment.

## Assumptions

- The `media` category stays in `packages.yaml` because media tools (ffmpeg, imagemagick, mpv) are general-purpose utilities not gated by a specific feature flag.
- The `other` category remains as a catch-all for packages that don't belong to any domain. Only packages clearly tied to a feature-flagged domain are relocated.
- Existing domain data files (e.g., `data/fonts.yaml`, `data/desktop.yaml`) are the preferred destination for relocated packages. New data files are created only when a domain state currently has no data file.
- The `audio` category in `packages.yaml` is nearly empty (just `pipewire` as placeholder) — `audio.sls` already manages the full audio stack. Migration is minimal.
- The `gaming` category is already empty — `steam.sls` manages all gaming packages. Only the category key needs removal.
- Packages that are genuinely shared across multiple domains stay in `packages.yaml` as infrastructure packages.

## Scope Boundaries

**In scope**:
- Removing domain categories from `packages.yaml`
- Relocating packages to domain states/data files
- Updating `packages.sls` category loop
- Auditing `other`/`aur` for misplaced domain packages
- Adding a lint check for zero-overlap enforcement

**Out of scope**:
- Restructuring domain states themselves (e.g., splitting `desktop.sls`)
- Changing the `host.features.*` flag system
- Modifying macro behavior (`pacman_install`, `paru_install`)
- Adding new feature flags for existing domains
