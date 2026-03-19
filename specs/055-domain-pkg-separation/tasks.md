# Tasks: Domain Package Separation

**Input**: Design documents from `/specs/055-domain-pkg-separation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested in spec. Lint script (FR-009) serves as the automated verification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Verify current state and capture baseline before any changes

- [ ] T001 Run `just validate` and capture baseline output to confirm current state is clean
- [ ] T002 Verify no existing `require` references to `pkg_audio`, `pkg_fonts`, `pkg_gaming`, `pkg_desktop` state IDs across all `.sls` files in `states/`

**Checkpoint**: Baseline verified — safe to begin migration

---

## Phase 2: Foundational — Remove Domain Categories from packages.yaml

**Purpose**: Remove the 4 domain categories from `packages.yaml` and update the `packages.sls` loop. This MUST complete before domain states can absorb their packages.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Remove `audio:` category (and its packages) from `states/data/packages.yaml`
- [ ] T004 [P] Remove `fonts:` category (and its packages) from `states/data/packages.yaml`
- [ ] T005 [P] Remove `gaming:` category (empty, just the key) from `states/data/packages.yaml`
- [ ] T006 [P] Remove `desktop:` category from `states/data/packages.yaml`; move `eza`, `television`, `yazi` to `other:` category with their inline comments preserved
- [ ] T007 Update the category loop in `states/packages.sls` line 13: remove `'audio'`, `'fonts'`, `'gaming'`, `'desktop'` from the iteration list
- [ ] T008 Run `just validate` to confirm Salt still renders with reduced categories

**Checkpoint**: `packages.yaml` has only 7 categories (`base`, `dev`, `network`, `media`, `system`, `other`, `aur`). Salt renders cleanly.

---

## Phase 3: User Story 1 — Trace Any Package to Its Owning Domain (Priority: P1) 🎯 MVP

**Goal**: Every package removed from `packages.yaml` is relocated to exactly one domain state, eliminating dual ownership.

**Independent Test**: Search for any relocated package across `packages.yaml` and `*.sls` files — it appears in exactly one location.

### Implementation for User Story 1

- [ ] T009 [US1] Add `pipewire` to the inline package loop in `states/audio.sls` (the `{% for pkg in [...] %}` list around line 5)
- [ ] T010 [P] [US1] Add `noto-fonts-cjk` with inline comment to the `pacman:` list in `states/data/fonts.yaml`
- [ ] T011 [P] [US1] Add new `packages:` top-level key to `states/data/desktop.yaml` containing 16 relocated desktop packages with inline comments: broot, dunst, hypridle, hyprland, hyprlock, hyprpolkitagent, loupe, matugen, nyxt, rmpc, rofi, swayimg, swayosd, wl-clip-persist, xdg-desktop-portal-gtk, xdg-desktop-portal-hyprland
- [ ] T012 [US1] Add a `pacman_install` call in `states/desktop.sls` that consumes the new `desktop_data.packages` list from `data/desktop.yaml` (following the existing `import_yaml` pattern already in the file)
- [ ] T013 [US1] Run `just validate` to confirm all states render cleanly after relocation

**Checkpoint**: All 21 packages have exactly one declaration point. `just validate` passes.

---

## Phase 4: User Story 2 — Packages.sls Contains Only Infrastructure Packages (Priority: P1)

**Goal**: `packages.sls` is verified to contain only infrastructure categories. The category loop matches the reduced set.

**Independent Test**: Read `packages.sls` — the loop iterates only `base`, `dev`, `network`, `media`, `system`, `other`.

### Implementation for User Story 2

- [ ] T014 [US2] Verify `packages.sls` category loop (modified in T007) matches exactly: `['base', 'dev', 'network', 'media', 'system', 'other']`
- [ ] T015 [US2] Verify `packages.yaml` AUR section: check if `iosevka-neg-fonts` appears in `aur:` list — if so, remove it (already managed by `fonts.sls` PKGBUILD)
- [ ] T016 [US2] Run `just apply` to confirm all packages are still installed with no regressions

**Checkpoint**: `packages.sls` is infrastructure-only. Full apply succeeds.

---

## Phase 5: User Story 3 — Domain States Are Self-Contained (Priority: P2)

**Goal**: Each domain state declares all its packages without depending on `packages.yaml`.

**Independent Test**: Disable a feature flag, run `just validate` — no errors from missing packages.

### Implementation for User Story 3

- [ ] T017 [US3] Verify `audio.sls` package list is complete: `pipewire`, `pipewire-audio`, `wireplumber`, `pipewire-pulse`, `pipewire-alsa`, `pipewire-jack`, `alsa-utils`, `playerctl` — all with inline comments
- [ ] T018 [P] [US3] Verify `fonts.sls` / `data/fonts.yaml` `pacman:` list includes `noto-fonts-cjk` alongside existing fonts — all with inline comments
- [ ] T019 [P] [US3] Verify `desktop.sls` correctly imports and installs all packages from `data/desktop.yaml` `packages:` list — all with inline comments
- [ ] T020 [US3] Run `just validate` with a test render confirming domain states are self-contained

**Checkpoint**: All domain states are self-contained. Feature flags control package installation cleanly.

---

## Phase 6: User Story 4 — Audit `other` and `aur` Categories (Priority: P3)

**Goal**: Domain-specific packages in catch-all categories are identified and relocated if appropriate.

**Independent Test**: Review each relocated package — it's only needed when a specific feature flag is enabled.

### Implementation for User Story 4

- [ ] T021 [US4] Audit audio-related packages in `other`/`aur` (`carla`, `cava`, `lsp-plugins`, `sonic-visualiser`, `sox`, `brutefir`, `pipemixer`, `raysession`) — document decision for each (keep or move) as comments in the commit message
- [ ] T022 [P] [US4] Audit font-related packages in `aur` (`ttfautohint`) — document decision (keep or move)
- [ ] T023 [US4] Execute any relocations identified in T021/T022 to appropriate domain states

**Checkpoint**: `other`/`aur` audit complete. All domain-specific packages identified and handled.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Lint enforcement, tooling updates, final verification

- [ ] T024 Create `scripts/lint-pkg-overlap.py` that parses `states/data/packages.yaml` and domain data files (`fonts.yaml`, `desktop.yaml`) plus inline package lists in `audio.sls` and `steam.sls` to detect overlapping package declarations
- [ ] T025 [P] Add `lint-pkg-overlap.py` to the `just lint` recipe in `Justfile`
- [ ] T026 [P] Update `scripts/pkg-snapshot.zsh` (around line 147) to parse `states/data/desktop.yaml` for domain-managed packages
- [ ] T027 Run `just lint` to verify the new overlap lint passes
- [ ] T028 Run `just validate` and `just apply` for final verification — capture clean output
- [ ] T029 Add unit test for overlap detection in `tests/unit/test_pkg_overlap.py`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — core migration
- **US2 (Phase 4)**: Depends on Phase 3 (packages must be relocated before verifying infrastructure-only)
- **US3 (Phase 5)**: Depends on Phase 3 (domain states must have their packages before self-containment verification)
- **US4 (Phase 6)**: Depends on Phase 3 — can run in parallel with US2/US3
- **Polish (Phase 7)**: Depends on Phases 3-6

### User Story Dependencies

- **US1 (P1)**: Core migration — must complete first
- **US2 (P1)**: Verification of US1 outcome — sequential after US1
- **US3 (P2)**: Self-containment verification — can start after US1, parallel with US2
- **US4 (P3)**: Audit pass — can start after US1, parallel with US2/US3

### Within Each User Story

- Data file changes before state file changes
- State file changes before validation
- Validation before moving to next phase

### Parallel Opportunities

**Phase 2** (Foundational):
```
T003, T004, T005, T006 — all modify different sections of packages.yaml (can be done as one edit)
```

**Phase 3** (US1):
```
T009, T010, T011 — different files (audio.sls, fonts.yaml, desktop.yaml)
```

**Phase 6** (US4):
```
T021, T022 — independent audit tasks
```

**Phase 7** (Polish):
```
T024, T025, T026 — different files (lint script, Justfile, pkg-snapshot.zsh)
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup (baseline)
2. Complete Phase 2: Remove categories from `packages.yaml`
3. Complete Phase 3: Relocate packages to domain states
4. Complete Phase 4: Verify infrastructure-only
5. **STOP and VALIDATE**: `just validate` + `just apply`
6. At this point the core separation is done — system works correctly

### Incremental Delivery

1. Setup + Foundational → categories removed
2. US1 → packages relocated → validate (MVP!)
3. US2 → infrastructure verified → apply
4. US3 → self-containment verified
5. US4 → audit complete
6. Polish → lint guard prevents regression

---

## Notes

- T003-T006 logically modify the same file (`packages.yaml`) — execute as a single coherent edit despite being listed separately for traceability
- The `gaming:` category removal (T005) is trivial — it's already empty
- T012 is the most complex task: `desktop.sls` needs a new `pacman_install` call wired to `desktop_data.packages`
- T024 (lint script) follows the established `scripts/lint-*.py` pattern (see `lint-ownership.py` for reference)
- Rollback via `just rollback` if `just apply` shows regressions
