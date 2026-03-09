# Tasks: Salt Package Management with Minimal Dependency Coverage

**Input**: Design documents from `/specs/008-salt-pkg-management/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Not explicitly requested — no test tasks included.

**Organization**: Tasks are grouped by user story. US1 and US3 are merged because categorization (US3) is an integral part of the snapshot tool (US1).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: No project initialization needed — all infrastructure (Salt, macros, data directory) already exists. This phase verifies prerequisites.

- [x] T001 Verify `pacman-contrib` is installed (provides `pactree` for reduction pass): `pacman -Qi pacman-contrib`

---

## Phase 2: User Story 1+3 — Capture & Categorize Package State (Priority: P1+P2) 🎯 MVP

**Goal**: Create `scripts/pkg-snapshot.zsh` that captures `pacman -Qqe` into a categorized `states/data/packages.yaml`, excluding packages managed by domain-specific Salt states. Includes optional `--reduce` flag for transitive dependency analysis.

**Independent Test**: Run `./scripts/pkg-snapshot.zsh`, verify `states/data/packages.yaml` is produced. Compare package count against `pacman -Qqe | wc -l` minus packages found in `.sls` files. Run `./scripts/pkg-snapshot.zsh --reduce` and verify reduction candidates are printed to stdout.

### Implementation

- [x] T002 [US1] Create `scripts/pkg-snapshot.zsh` with shebang (`#!/usr/bin/env zsh`), `set -euo pipefail`, usage/help text, and argument parsing (`--reduce`, `--dry-run`, `--help`) in `scripts/pkg-snapshot.zsh`
- [x] T003 [US1] Implement `.sls` cross-reference function in `scripts/pkg-snapshot.zsh`: parse all `states/*.sls` files to extract package names from `pacman_install(name, 'pkg1 pkg2 ...')` and `paru_install(name, 'pkg')` macro calls using grep/regex. Store results in an associative array for O(1) lookup.
- [x] T004 [US1] Implement baseline capture in `scripts/pkg-snapshot.zsh`: run `pacman -Qqe` to get all explicitly-installed packages, filter out packages found in the `.sls` cross-reference, and separate remaining packages into official vs AUR (using `pacman -Qqm` for foreign/AUR detection).
- [x] T005 [US3] Implement auto-categorization in `scripts/pkg-snapshot.zsh`: assign packages to categories (`base`, `desktop`, `dev`, `network`, `audio`, `media`, `fonts`, `gaming`, `system`, `aur`, `other`) using pacman group membership (`pacman -Qg`), repository metadata, and keyword heuristics. AUR packages go under `aur:` key regardless of domain.
- [x] T006 [US1] Implement YAML output in `scripts/pkg-snapshot.zsh`: write categorized packages to `states/data/packages.yaml` following the schema in `data-model.md`. Include header comment explaining the file's purpose and relationship to domain-specific states. Empty categories for domains managed by other states (audio, fonts, gaming) include a `# NOTE:` comment referencing the owning `.sls` file.
- [x] T007 [US1] Implement `--reduce` flag in `scripts/pkg-snapshot.zsh`: for each explicit package, use `pactree -r <pkg>` to check if it's a dependency of another explicit package. Print reduction candidates to stdout with their dependents (format per `data-model.md` Reduction Candidates entity). Do NOT modify `packages.yaml` — output is advisory only.
- [x] T008 [US1] Run `scripts/pkg-snapshot.zsh` on the live system to generate initial `states/data/packages.yaml`. Review output for correctness: verify no domain-managed packages are present, AUR packages are correctly identified, and categories make sense.

**Checkpoint**: `states/data/packages.yaml` exists with categorized packages. Running `--reduce` shows candidates. All domain-managed packages are excluded.

---

## Phase 3: User Story 2 — Declarative Package Management via Salt (Priority: P1)

**Goal**: Create `states/packages.sls` that reads `states/data/packages.yaml` and installs all listed packages idempotently using existing macros. Add it to the system_description include list.

**Independent Test**: Run `just` (salt-call test=True). All packages should show as already installed (no changes). Add a test package to `packages.yaml`, run `just`, verify it would be installed.

### Implementation

- [x] T009 [US2] Create `states/packages.sls`: import macros via `_imports.jinja`, load `states/data/packages.yaml` via `import_yaml`, iterate each category. For non-`aur` categories: join package list into space-separated string and call `pacman_install(category_name, joined_pkgs, check=last_pkg)`. For `aur` category: loop and call `paru_install(pkg, pkg)` per package. Skip empty categories. File path: `states/packages.sls`
- [x] T010 [US2] Add `packages` to the include list in `states/system_description.sls`. Place it early in the list (after `users` and `zsh`, before domain-specific states) so base packages are available for subsequent states.
- [x] T011 [US2] Run `just` to verify Salt renders cleanly with the new `packages.sls` included. All states should pass — no packages should need installation since `packages.yaml` was generated from the current system state.

**Checkpoint**: `salt-call state.apply` succeeds. Adding a package to `packages.yaml` and re-running shows it would be installed. Existing domain states are unaffected.

---

## Phase 4: User Story 4 — Package Drift Detection (Priority: P3)

**Goal**: Create `scripts/pkg-drift.zsh` that compares declared packages against actual system state and reports discrepancies.

**Independent Test**: Run `./scripts/pkg-drift.zsh`, verify it reports no drift (since `packages.yaml` was just generated). Manually install a test package (`pacman -S cowsay`), re-run, verify it appears under UNMANAGED.

### Implementation

- [x] T012 [P] [US4] Create `scripts/pkg-drift.zsh` with shebang (`#!/usr/bin/env zsh`), `set -euo pipefail`, and argument parsing (`--quiet` for exit-code-only mode, `--help`) in `scripts/pkg-drift.zsh`
- [x] T013 [US4] Implement declared package collection in `scripts/pkg-drift.zsh`: parse `states/data/packages.yaml` (extract all package names from all categories) and parse `states/*.sls` files for `pacman_install`/`paru_install` macro calls (same logic as `pkg-snapshot.zsh`). Union of both sets = "declared packages."
- [x] T014 [US4] Implement drift comparison in `scripts/pkg-drift.zsh`: compare declared set against `pacman -Qqe` (actual explicit). Report three categories per `data-model.md` Drift Report entity: UNMANAGED (in actual but not declared), MISSING (in declared but not actual), ORPHANS (from `pacman -Qdtq`). Print summary line with counts. Exit code 0 if no drift, 1 if any discrepancy found.
- [x] T015 [US4] Add `pkg-drift` recipe to `Justfile`: `just pkg-drift` runs `./scripts/pkg-drift.zsh`

**Checkpoint**: Running `scripts/pkg-drift.zsh` reports clean state. Manually installing/removing a package and re-running shows correct drift detection.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates, CLAUDE.md policy change, final verification.

- [x] T016 [P] Update `CLAUDE.md`: change "Packages installed via pacman/paru outside Salt" to reflect that Salt now manages package installation via `states/data/packages.yaml`. Add `packages.sls` to the Salt State Modules table. Add `scripts/pkg-snapshot.zsh` and `scripts/pkg-drift.zsh` to Key Paths table.
- [x] T017 [P] Add `pkg-snapshot` recipe to `Justfile`: `just pkg-snapshot` runs `./scripts/pkg-snapshot.zsh`
- [x] T018 Run final `just` verification to confirm all states render cleanly with the complete implementation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — verify prerequisites
- **Phase 2 (US1+US3)**: Depends on Phase 1 — produces `packages.yaml`
- **Phase 3 (US2)**: Depends on Phase 2 — `packages.sls` consumes `packages.yaml`
- **Phase 4 (US4)**: Depends on Phase 2 — reads `packages.yaml` for comparison. Can run in parallel with Phase 3.
- **Phase 5 (Polish)**: Depends on Phases 3 and 4

### User Story Dependencies

- **US1+US3 (Capture & Categorize)**: No dependencies — foundational
- **US2 (Salt Management)**: Depends on US1+US3 (needs `packages.yaml` to exist)
- **US4 (Drift Detection)**: Depends on US1+US3 (needs `packages.yaml`). Independent of US2.

### Parallel Opportunities

- **Phase 3 + Phase 4**: Can run in parallel after Phase 2 completes (different files, no dependencies)
- **T012-T015 (US4)** and **T009-T011 (US2)**: Independent — different files, different concerns
- **T016 + T017**: Independent documentation/Justfile updates

---

## Parallel Example: After Phase 2

```bash
# These can run simultaneously:
# Stream A: User Story 2 (Salt state)
Task: "Create packages.sls in states/packages.sls"
Task: "Add packages to include list in states/system_description.sls"

# Stream B: User Story 4 (Drift detection)
Task: "Create pkg-drift.zsh in scripts/pkg-drift.zsh"
Task: "Implement drift comparison logic"
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2 + Phase 3)

1. Verify prerequisites (T001)
2. Create `pkg-snapshot.zsh` and generate `packages.yaml` (T002–T008)
3. Create `packages.sls` and integrate into Salt (T009–T011)
4. **STOP and VALIDATE**: Run `just`, confirm clean apply
5. This alone delivers the core value: declarative package management via Salt

### Incremental Delivery

1. MVP (US1+US2+US3) → Package management works, categories organized
2. Add US4 (Drift Detection) → Maintenance visibility
3. Polish → Documentation, Justfile recipes

### Single Developer Strategy

1. Complete Phases 1–3 sequentially (MVP in ~2-3 hours)
2. Add Phase 4 (drift detection, ~1 hour)
3. Polish (Phase 5, ~30 min)
4. Run final verification

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US3 (Categorization) is merged into US1 because categorization is built into the snapshot tool
- Commit after each phase checkpoint
- The initial `packages.yaml` generation (T008) is a one-shot human-reviewed step — verify output before proceeding to Phase 3
