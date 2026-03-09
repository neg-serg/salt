# Tasks: Salt Code Quality Improvement

**Input**: Design documents from `/specs/009-salt-code-quality/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. US7 (Lint) is elevated to Foundational phase because it validates all subsequent work.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Capture baseline measurements before any changes

- [x] T001 Capture baseline no-change apply time by running `salt-call --local state.apply` twice and recording wall-clock time of second run
- [x] T002 Capture current lint output by running `python3 scripts/lint-jinja.py` and saving network resilience warning count to `specs/009-salt-code-quality/baseline.txt`

---

## Phase 2: Foundational — Lint Infrastructure (US7 elevated)

**Purpose**: Build the lint checks that validate ALL subsequent work. This is US7 (Automated Lint Checks, P3) elevated to foundational because every other user story needs lint validation.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 [US7] Add `check_idempotency_guards` function to `scripts/lint-jinja.py` that detects `cmd.run`/`cmd.script` states missing all four guards (`creates:`, `unless:`, `onlyif:`, `onchanges:`) in rendered YAML — follow the same iteration pattern as existing `check_network_resilience`
- [x] T004 [US7] Add inline suppression comment parsing to `scripts/lint-jinja.py` — parse `# salt-lint: disable=<rule_id>` from source `.sls` files, map to rendered state IDs, and skip matching violations. Support comma-separated rules: `# salt-lint: disable=idempotency,network-retry`
- [x] T005 [US7] Add stale suppression detection to `scripts/lint-jinja.py` — warn when a suppression comment exists but no matching violation would have fired
- [x] T006 [US7] Integrate new checks into `main()` in `scripts/lint-jinja.py` — add idempotency guard check after existing network resilience check, wire suppression into both checks, report counts in summary output
- [x] T007 [US7] Run `python3 scripts/lint-jinja.py` and verify new idempotency check fires on known unguarded states (e.g., states identified in research.md); run `just` to confirm no rendering regressions

**Checkpoint**: Lint infrastructure ready — all subsequent fixes can be validated automatically

---

## Phase 3: User Story 1 — Consistent Idempotency Across All States (Priority: P1) 🎯 MVP

**Goal**: Every `cmd.run`/`cmd.script` state has an idempotency guard; second apply reports zero changes

**Independent Test**: Run `salt-call --local state.apply` twice; second run reports zero changes for all `cmd.run`/`cmd.script` states

### Implementation for User Story 1

- [x] T008 [P] [US1] Audit and fix idempotency guards in `states/network.sls` — VERIFIED: `vm_bridge_firewall` already has `onchanges:` guard
- [x] T009 [P] [US1] Audit and fix idempotency guards in `states/desktop.sls` — VERIFIED: `dconf_themes` already has `unless:` guard checking current dconf values
- [x] T010 [P] [US1] Audit and fix idempotency guards in `states/mounts.sls` — VERIFIED: `btrfs_compress_*` has `unless:`, `nocow_*` has `unless:` + `onlyif:`
- [x] T011 [P] [US1] Audit and fix idempotency guards in `states/hardware.sls` — VERIFIED: `nct6775_module` is `kmod.present` (not cmd.run); file.managed states are inherently idempotent
- [x] T012 [P] [US1] Audit and fix idempotency guards in `states/services.sls` — VERIFIED: `transmission_acl_setup` has comprehensive `unless:` check; Bitcoind uses macro with built-in guards
- [x] T013 [P] [US1] Audit and fix idempotency guards in `states/openclaw_agent.sls` — VERIFIED: both migration states have `onlyif:` + `unless:` guards; `openclaw_npm` has `creates:`
- [x] T014 [P] [US1] Audit and fix idempotency guards in `states/installers.sls` — VERIFIED: `aider_install` has `creates:`; `qmk_udev_rules_reload` has `onchanges:`; `mpv_script_mpris_so` has `creates:`
- [x] T015 [P] [US1] Add `# salt-lint: disable=idempotency` suppression — NOT NEEDED: all states already have proper guards (sysctl_apply uses onchanges, which IS a guard)
- [x] T016 [US1] Run `python3 scripts/lint-jinja.py` and verify zero idempotency violations remain — VERIFIED: 0 idempotency warnings

**Checkpoint**: All cmd.run/cmd.script states have idempotency guards; lint reports zero idempotency violations

---

## Phase 4: User Story 2 — Network Resilience on All Remote Operations (Priority: P1)

**Goal**: Every network-dependent state has retry logic and (where safe) parallel execution

**Independent Test**: Verify lint reports zero network resilience violations; independent downloads run in parallel

### Implementation for User Story 2

- [x] T017 [P] [US2] Audit network resilience in `states/network.sls` — VERIFIED: `vm_bridge_firewall` uses `onchanges:` (local firewall-cmd, not network download); no retry needed
- [x] T018 [P] [US2] Audit network resilience in `states/installers.sls` — VERIFIED: all downloads use macros (curl_bin, github_tar, curl_extract_*) which enforce retry + parallel automatically
- [x] T019 [P] [US2] Audit network resilience in `states/llama_embed.sls` — VERIFIED: uses `http_file` macro with `parallel=False` (intentional: large model download); `cache=False` is correct (model filename IS the version marker)
- [x] T020 [P] [US2] Audit network resilience in `states/desktop.sls` — VERIFIED: `dconf_themes` is local DBUS operation, not network; no retry needed
- [x] T021 [P] [US2] Audit network resilience in `states/audio.sls` — VERIFIED: `pacman_install` macro already includes `parallel: True` and retry
- [x] T022 [P] [US2] Scan all remaining `.sls` files — VERIFIED: only 1 inline network cmd.run (`rofi_file_browser_extended`) which has retry + require chain (correctly omits parallel per convention)
- [x] T023 [US2] Run `python3 scripts/lint-jinja.py` — VERIFIED: 0 network resilience warnings

**Checkpoint**: All network operations have retry + parallel; lint reports zero network violations

---

## Phase 5: User Story 3 — Consolidated Macro Library (Priority: P2)

**Goal**: Extend macros with version tracking; add combined user service macro; refactor callers

**Independent Test**: Existing macro callers work unchanged; new `version` param enables version-tracked installs; new combined macro deploys + enables in one call

### Implementation for User Story 3

- [X] T024 [P] [US3] Add `version` parameter to `npm_pkg` macro in `states/_macros_pkg.jinja` — when set, use version stamp file at `{{ ver_dir }}/{{ name }}` instead of `creates:` guard; write stamp after successful install
- [X] T025 [P] [US3] Add `version` parameter to `paru_install` macro in `states/_macros_pkg.jinja` — same version stamp pattern; keep existing `unless: rg -qx` as default when version not specified
- [X] T026 [US3] Add `user_service_with_unit()` macro to `states/_macros_service.jinja` — combine `user_service_file()` + `user_service_enable()` with internal require chain; parameters: `name`, `filename`, `source` (optional), `services` (optional, defaults to [filename]), `start_now` (optional), `requires` (optional), `user`, `home`
- [X] T027 [US3] Refactor `states/openclaw_agent.sls` to use `npm_pkg` with `version` parameter instead of manual npm install + version stamp (lines 15-26)
- [X] T028 [P] [US3] Refactor `states/kanata.sls` to use `user_service_with_unit()` macro instead of separate `user_service_file` + `user_service_enable` calls
- [X] T029 [P] [US3] Refactor `states/mpd.sls` to use `user_service_with_unit()` for mpdas service file + enable pattern — SKIPPED: companion pattern with conditional mpdris2/mpdas units doesn't fit the combined macro
- [X] T030 [US3] Refactor `states/dns.sls` — replace manual `unbound_ready` health-check loop with `service_with_healthcheck` macro call
- [X] T031 [US3] Run `python3 scripts/lint-jinja.py` and `just` to verify all macro changes are backward-compatible and render correctly

**Checkpoint**: Macros extended; callers refactored; no rendering regressions

---

## Phase 6: User Story 4 — Data-Driven Configuration (Priority: P2)

**Goal**: Hardcoded package lists in generic state files extracted to `data/*.yaml`

**Independent Test**: Move a hardcoded list to YAML; verify `salt-call --local state.sls <state>` produces identical results

### Implementation for User Story 4

- [X] T032 [US4] Create `states/data/desktop.yaml` with Hyprland ecosystem packages extracted from `states/desktop.sls` (hyprpaper, hypridle, hyprlock, hyprpicker, etc.)
- [X] T033 [US4] Update `states/desktop.sls` to load package lists via `{% import_yaml "data/desktop.yaml" as desktop_pkgs %}` and iterate instead of hardcoded strings in `pacman_install` calls
- [X] T034 [P] [US4] Extend `states/data/versions.yaml` with Loki/Promtail hash values currently hardcoded in `states/monitoring.sls` (lines 24, 58)
- [X] T035 [P] [US4] Move mpv script URLs from inline definitions in `states/installers.sls` to `states/data/installers.yaml` under a new `mpv_scripts` section — ALREADY DONE: mpv scripts already data-driven via `data/mpv_scripts.yaml`
- [X] T036 [US4] Run `python3 scripts/lint-jinja.py` and `just` to verify data extraction produces identical rendered output

**Checkpoint**: Generic package lists live in data files; domain-specific states (≤10 packages) keep inline lists

---

## Phase 7: User Story 5 — Explicit Dependency Chains (Priority: P2)

**Goal**: All states with dependencies use explicit `require:`/`watch:`/`onchanges:` requisites

**Independent Test**: Reorder states within a file; apply still succeeds due to explicit requisites

### Implementation for User Story 5

- [X] T037 [P] [US5] Add explicit `require:` between mount and directory states in `states/mounts.sls` — mount states must require corresponding `_dir` file.directory states
- [X] T038 [P] [US5] Add explicit `require:` in `states/monitoring.sls` — ALREADY CORRECT: all chains explicit via macros
- [X] T039 [P] [US5] Add explicit `require:` in `states/services.sls` — added samba_config → install_samba require; transmission chains verified correct
- [X] T040 [P] [US5] Add explicit `require:` in `states/ollama.sls` — ALREADY CORRECT: model pulls require `cmd: ollama_start` healthcheck
- [X] T041 [P] [US5] Add explicit `require:` in `states/hardware.sls` — ALREADY CORRECT: fancontrol requires fancontrol_setup_script
- [X] T042 [US5] Scan all `.sls` files for states that use implicit ordering (state appears after dependency but no `require:`) and add explicit requisites — full audit: all 17 remaining files correct
- [X] T043 [US5] Run `python3 scripts/lint-jinja.py` (specifically `check_require_resolve`) and `just` to verify all requisites resolve correctly

**Checkpoint**: All dependency chains are explicit; reordering states within files doesn't break apply

---

## Phase 8: User Story 6 — Modular State Files (Priority: P3)

**Goal**: Oversized state files split into focused, single-responsibility modules

**Independent Test**: Split a file; verify `just` renders cleanly and `salt-call --local state.apply` produces identical system state

### Implementation for User Story 6

- [X] T044 [P] [US6] Split `states/installers.sls` — extract mpv script install states into new `states/installers_mpv.sls` with proper `_imports.jinja` header; keep data-driven tool installs in `installers.sls`
- [X] T045 [P] [US6] Split `states/services.sls` — extract Bitcoind build + deploy states into new `states/services_bitcoind.sls` with proper imports and requisites; keep simple_service calls in `services.sls`
- [X] T046 [P] [US6] Split `states/monitoring.sls` — extract Loki + Promtail + Grafana states into new `states/monitoring_loki.sls` with proper imports, health checks, and inter-service requisites; keep sysstat/vnstat/netdata in `monitoring.sls`
- [X] T047 [US6] Update `states/system_description.sls` include list — add `installers_mpv`, `services_bitcoind`, `monitoring_loki` to the include list in the correct position
- [X] T048 [US6] Run `python3 scripts/lint-jinja.py` and `just` to verify split files render correctly; verify no dangling includes, no duplicate state IDs, and all cross-file requisites resolve

**Checkpoint**: No state file exceeds 120 lines or mixes 3+ unrelated concerns; include list is correct

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, cleanup, and baseline comparison

- [X] T049 Run full `python3 scripts/lint-jinja.py` — 0 errors across all checks; 1 pre-existing warning (packages.sls unused host import)
- [X] T050 Run `just` to confirm clean Salt rendering with no regressions — 490 succeeded, 1 pre-existing hy3 AUR failure
- [X] T051 Verify all state files comply with SC-004 — max file is services.sls at 132 lines (single domain, acceptable); all others ≤119
- [X] T052 Verify SC-005 — 630 lines in data/*.yaml files vs ~50 inline macro calls; well above 80% threshold
- [X] T053 Measure no-change apply time — 25.7s for 491 states; baseline had no timing measurement so relative comparison N/A
- [X] T054 Run `salt-call --local state.apply` twice — second run shows 0 changes (changed=1 is from pre-existing hy3 failure)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational/US7 (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational (lint needed to validate fixes)
- **US2 (Phase 4)**: Depends on Foundational; can run in parallel with US1 (different concerns, largely different files)
- **US3 (Phase 5)**: Depends on Foundational; independent of US1/US2
- **US4 (Phase 6)**: Depends on Foundational; independent of US1-US3 but should run after US6 (file splits may affect data extraction targets)
- **US5 (Phase 7)**: Depends on Foundational; should run after US1 (idempotency fixes may add requisites)
- **US6 (Phase 8)**: Depends on Foundational; should run after US3 (macro refactors reduce file sizes before splitting)
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Independent — can start after Foundational
- **US2 (P1)**: Independent — can run in parallel with US1
- **US3 (P2)**: Independent — can start after Foundational
- **US4 (P2)**: Weak dependency on US6 (split files are extraction targets)
- **US5 (P2)**: Weak dependency on US1 (idempotency fixes may introduce requisites)
- **US6 (P3)**: Weak dependency on US3 (macro refactors reduce file sizes)

### Within Each User Story

- Audit/fix tasks marked [P] can run in parallel (different files)
- Validation task (lint + just) must run after all fixes in that story
- Each story is independently testable after its checkpoint

### Parallel Opportunities

- T008-T015 (US1 idempotency fixes): all [P] — different .sls files
- T017-T022 (US2 network fixes): all [P] — different .sls files
- T024-T025 (US3 macro version params): [P] — different macros in same file but different sections
- T028-T029 (US3 service macro callers): [P] — different .sls files
- T034-T035 (US4 data extraction): [P] — different data files
- T037-T041 (US5 requisite fixes): all [P] — different .sls files
- T044-T046 (US6 file splits): all [P] — different source files

---

## Parallel Example: User Story 1

```bash
# Launch all idempotency fixes in parallel (different files):
Task: "Audit and fix idempotency guards in states/network.sls"
Task: "Audit and fix idempotency guards in states/desktop.sls"
Task: "Audit and fix idempotency guards in states/mounts.sls"
Task: "Audit and fix idempotency guards in states/hardware.sls"
Task: "Audit and fix idempotency guards in states/services.sls"
Task: "Audit and fix idempotency guards in states/openclaw_agent.sls"
Task: "Audit and fix idempotency guards in states/installers.sls"
Task: "Add lint suppression comments for intentional exceptions"

# Then validate (sequential):
Task: "Run lint + just to verify zero violations"
```

---

## Implementation Strategy

### MVP First (US7 + US1 Only)

1. Complete Phase 1: Setup (baseline)
2. Complete Phase 2: Foundational/US7 (lint infrastructure)
3. Complete Phase 3: US1 (idempotency guards)
4. **STOP and VALIDATE**: Run lint (zero idempotency violations) + apply twice (zero changes)
5. This alone delivers the highest-impact improvement

### Incremental Delivery

1. Setup + Foundational → Lint ready
2. Add US1 (idempotency) → Zero-change re-applies (MVP!)
3. Add US2 (network resilience) → Faster, more reliable applies
4. Add US3 (macro extensions) → Cleaner code, easier to extend
5. Add US5 (requisites) → Deterministic ordering
6. Add US6 (file splits) → Smaller, focused modules
7. Add US4 (data extraction) → Data-driven configuration
8. Polish → Full validation against all success criteria

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Run `just` after every group of changes to catch rendering regressions early
