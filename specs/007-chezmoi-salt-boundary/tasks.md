# Tasks: Chezmoi/Salt File Ownership Boundary

**Input**: Design documents from `/specs/007-chezmoi-salt-boundary/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Not requested — no test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: User Story 1 — Eliminate Dual-Write File Conflicts (Priority: P1) MVP

**Goal**: Each of the 8 currently dual-written files has exactly one owner. No file is deployed by both Salt and chezmoi.

**Independent Test**: Run `just` to verify Salt renders with 0 failures. Grep `salt://dotfiles/` references in `.sls` files and confirm each has a matching `.chezmoiignore` entry. Verify `dotfiles/dot_config/proxypilot/` directory no longer exists.

### Implementation for User Story 1

- [x] T001 [P] [US1] Add 5 floorp entries to `dotfiles/.chezmoiignore` — append comment block `# Floorp browser: Salt deploys to ~/.floorp/<profile>/ (non-XDG path)` followed by entries: `.config/floorp/user.js`, `.config/floorp/userChrome.css`, `.config/floorp/userContent.css`, `.config/floorp/custom/` (directory entry covers both CSS files inside). See data-model.md "Current State (after)" for exact format.
- [x] T002 [P] [US1] Delete `dotfiles/dot_config/proxypilot/config.yaml.tmpl` and remove the now-empty parent directory `dotfiles/dot_config/proxypilot/`. Salt uses separate source at `states/configs/proxypilot.yaml.j2`; the `.chezmoiignore` entry for `.config/proxypilot/config.yaml` already exists and should remain (Salt still deploys via `file.managed` in `states/opencode.sls`).
- [x] T003 [US1] Run `just` to verify Salt renders with 0 failures after ownership changes. Confirm no regressions in state rendering.

**Checkpoint**: All 8 files now have single ownership. Salt-sourced `dotfiles/` paths are fully covered by `.chezmoiignore`. Proxypilot has one source (Salt's Jinja2 template).

---

## Phase 2: User Story 2 — Establish Ownership Decision Policy (Priority: P2)

**Goal**: A clear, documented ownership policy in CLAUDE.md that any contributor (human or AI) can use to determine which tool should own a given config file.

**Independent Test**: Read the new CLAUDE.md section and determine ownership for a hypothetical config file — e.g., "new app config needing gopass secrets" → Salt; "new shell alias file" → chezmoi.

### Implementation for User Story 2

- [x] T004 [US2] Add ownership policy subsection to `CLAUDE.md` under Conventions. Include: (1) decision tree — Salt owns files requiring gopass secrets with fallback, watch/onchanges triggers, non-XDG deploy paths, or grain/pillar conditionals; chezmoi owns purely declarative dotfiles. (2) `.chezmoiignore` rule — files in `dotfiles/` sourced by Salt via `salt://dotfiles/` MUST be in `.chezmoiignore`. (3) Separate-source rule — files where Salt has its own template (e.g., `salt://configs/`) MUST NOT exist in `dotfiles/`. See quickstart.md "Ownership Decision Tree" for reference format.

**Checkpoint**: CLAUDE.md contains actionable ownership policy. No implementation details leak — policy is about what/why, not how.

---

## Phase 3: User Story 3 — Verify No Regressions via Lint (Priority: P3)

**Goal**: An automated lint script detects `salt://dotfiles/` references not covered by `.chezmoiignore`, integrated into `just lint`.

**Independent Test**: Run `just lint` — the new lint-ownership check passes. Temporarily remove a `.chezmoiignore` entry and re-run — lint fails with clear error message naming the uncovered path.

### Implementation for User Story 3

- [x] T005 [P] [US3] Create `scripts/lint-ownership.py` (~60 lines Python, stdlib only). Script must: (1) scan all `states/*.sls` files for `salt://dotfiles/` URI patterns using regex, (2) convert each URI to chezmoi-relative path (`dot_config/` → `.config/`, `dot_local/` → `.local/`), (3) load `dotfiles/.chezmoiignore` entries (strip comments, blank lines), (4) check each Salt-referenced path against `.chezmoiignore` entries (exact match or parent-directory match), (5) exit 0 if all covered, exit 1 with per-path error messages if violations found. Follow `scripts/lint-dotfiles.py` structure: shebang `#!/usr/bin/env python3`, docstring, `sys.exit(main())` pattern.
- [x] T006 [P] [US3] Add `.venv/bin/python3 scripts/lint-ownership.py` to `Justfile` `lint` recipe, inserting after the `lint-dotfiles.py` line (line 51).
- [x] T007 [US3] Run `just lint` to verify the new lint script passes with the updated `.chezmoiignore` from T001. All `salt://dotfiles/` references should be covered.

**Checkpoint**: Lint script integrated. Any future `salt://dotfiles/` reference without a `.chezmoiignore` entry will fail `just lint`.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final verification that all changes work together

- [x] T008 Run full `just` verification to confirm Salt renders successfully with all changes applied (0 failures, no regressions)
- [x] T009 Run `just lint` to verify all lint scripts pass (including the new lint-ownership.py)

---

## Dependencies & Execution Order

### Phase Dependencies

- **US1 (Phase 1)**: No dependencies — can start immediately. This is the MVP.
- **US2 (Phase 2)**: No dependencies on US1 — can run in parallel. Documentation-only.
- **US3 (Phase 3)**: T005/T006 can start in parallel with US1. T007 depends on T001 (needs updated `.chezmoiignore` to pass).
- **Polish (Phase 4)**: Depends on all phases completing.

### Within Each User Story

- US1: T001 and T002 are parallel (different files). T003 depends on both.
- US2: Single task, no internal dependencies.
- US3: T005 and T006 are parallel (different files). T007 depends on T001, T005, T006.

### Parallel Opportunities

```
Start immediately (all parallel):
  T001 [US1] .chezmoiignore update
  T002 [US1] Delete proxypilot template
  T004 [US2] CLAUDE.md ownership policy
  T005 [US3] Create lint-ownership.py
  T006 [US3] Update Justfile

After T001+T002 complete:
  T003 [US1] Verify Salt renders

After T001+T005+T006 complete:
  T007 [US3] Verify lint passes

After all complete:
  T008, T009 Polish verification
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete T001 + T002 (parallel)
2. Run T003: Verify Salt renders
3. **STOP and VALIDATE**: All dual-write conflicts eliminated
4. Ownership changes are safe and reversible (git revert if needed)

### Incremental Delivery

1. US1 (T001-T003) → Eliminates all 8 dual-writes → Core value delivered
2. US2 (T004) → Documents policy → Prevents regression via contributor education
3. US3 (T005-T007) → Automated enforcement → Prevents regression via CI/lint
4. Polish (T008-T009) → Final verification → Confidence for merge

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Total: 9 tasks (3 US1, 1 US2, 3 US3, 2 Polish)
- Maximum parallelism: 5 tasks can start simultaneously (T001, T002, T004, T005, T006)
- No test tasks generated (not requested in spec)
- Commit after each phase checkpoint per project commit conventions `[scope] description`
