# Salt Refactoring Recommendations

**Date**: 2026-03-24  
**Scope**: Repository-specific Salt refactoring proposals that improve maintainability without degrading no-op `just apply` performance.

## Goal

This document is not a generic Salt style guide. It is a targeted audit of this repository's current Salt tree, macros, data files, and helper scripts.

The bar for inclusion is strict:

- a proposal must improve maintainability in this repository
- it must preserve or improve no-op apply performance
- it must not fight the local constitution (`.specify/memory/constitution.md`)
- it must not replace explicit, readable Salt with meta-programming unless the repetition is both real and costly

## Evidence Base

The recommendations below are based on:

- `CLAUDE.md`
- `.specify/memory/constitution.md`
- `docs/salt-best-practices.md`
- `states/system_description.sls`
- `states/_imports.jinja`
- `states/_macros_*.jinja`
- domain states under `states/*.sls`
- declarative data under `states/data/*.yaml`
- validation/profiling tools such as `scripts/render-matrix.py` and `scripts/state-profiler.py`

## Recommendation Format

Each item follows the same shape:

- `Problem`: what is hard to maintain today
- `Recommendation`: what to change
- `Why here`: why it fits this repository rather than generic Salt advice
- `Performance impact`: `positive`, `neutral`, `uncertain`, or `negative`
- `Validation`: what to run after implementation

## Performance Guardrails

Classify a change as `safe now` only if it is expected to be neutral or positive for render/compile/no-op apply cost.

Move a change into `requires validation` if it:

- alters include structure
- changes how many states render for a host
- replaces explicit state blocks with loops/macros that are harder to reason about
- changes `cmd.run` / `cmd.script` sequencing or guard behavior

Move a change into `avoid for now` if it is likely to:

- widen the include graph
- increase Jinja indirection for cosmetic benefit only
- replace readable state logic with generic YAML schemas or nested meta-templates
- make debugging harder without reducing real duplication

## Backlog Status

| Item | Classification | Status | Notes |
| --- | --- | --- | --- |
| 1. Runtime-dir normalization | safe now | done on `071-salt-refactor-program` | `host.runtime_dir` now drives remaining user-session references |
| 2. Shared Hugging Face download path | safe now | done on `071-salt-refactor-program` | `video_ai` now uses shared macro path |
| 3. YAML-driven user-service feature tags | safe now | done on `071-salt-refactor-program` | parallel hardcoded lists removed from `user_services.sls` |
| 4. Shared Salt runtime bootstrap shell module | safe now | done on `071-salt-refactor-program` | `salt-apply.sh` and `salt-validate.sh` share one bootstrap implementation |
| 5. Extract `Justfile` lint recipe | safe now | done on `071-salt-refactor-program` | lint flow moved to `scripts/lint-all.sh` |
| 6. Narrow config+restart helper | requires validation | done on `071-salt-refactor-program` | applied only to the repeated Transmission settings pattern |
| 7. Contract tests for macros/rendering | safe now | done on `071-salt-refactor-program` | dedicated regression tests added under `tests/` |
| 8. CI performance gate | requires validation | done on `071-salt-refactor-program` | path-scoped PASS/FAIL/INCONCLUSIVE gate wired in CI |
| 9. Selective SLS decomposition | requires validation | done on `071-salt-refactor-program` | `video_ai` and `desktop` split into explicit thematic includes |
| 10. Keep refactor backlog synchronized | safe now | done on `071-salt-refactor-program` | this document and spec-kit tasks stay aligned |

## Validation Evidence

Latest verification pass on `071-salt-refactor-program`:

- `pytest tests/` → `48 passed`
- `just lint` → passed
- `just validate` → `Validated 49 states, 0 failed`
- `just render-matrix` → all matrix scenarios rendered successfully
- `python3 scripts/state-profiler.py --compare <baseline> <baseline> --gate --min-sample-count 10` → `PASS`

## Adoption Order

1. Land the already-implemented safe-now items first: runtime-dir normalization, shared downloads, YAML user-services, shared runtime bootstrap, lint extraction, contract tests, backlog sync.
2. Land the validation-gated but completed items with the recorded evidence: config+restart helper, CI perf gate, and selective SLS decomposition.
3. Keep future follow-ups narrow; do not widen include graphs or introduce meta-generated state topology.

## Safe Now

### REC-001: Replace hardcoded `/run/user/1000` references with `host.runtime_dir`

**Scope**: `states/desktop.sls`, `states/units/user/salt-monitor.service`

**Problem**: A few user-service and Hyprland-related paths are still hardcoded to `/run/user/1000`, while the rest of the repository already carries `host.runtime_dir`.

**Recommendation**: Replace the hardcoded runtime path with `host.runtime_dir` everywhere user-session state is rendered or exported.

**Why here**: This repository already models per-host runtime paths in Jinja. Keeping one source of truth avoids subtle drift if the user ID or runtime convention changes.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- inspect rendered user-service environment values for affected states

**Status**: done on feature branch `071-salt-refactor-program`

---

### REC-002: Introduce a small `ensure_linger` macro for repeated user-service lingering

**Scope**: `states/telethon_bridge.sls`, `states/nanoclaw.sls`, `states/_macros_service.jinja`

**Problem**: The same `loginctl enable-linger {{ user }}` + `Linger=yes` guard is duplicated three times.

**Recommendation**: Add a narrow `ensure_linger(name, user)` helper in `states/_macros_service.jinja` and use it in the three current call sites.

**Why here**: This is a repeated operational pattern with identical semantics, not a one-off abstraction. It matches the repository's existing macro-first rule.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- verify rendered state IDs remain distinct and readable

---

### REC-003: Centralize ProxyPilot credential fallback resolution

**Scope**: `states/telethon_bridge.sls`, `states/nanoclaw.sls`, `states/opencode.sls`

**Problem**: The same ProxyPilot API-key retrieval pattern appears in multiple states, with slight variations in how gopass and fallback parsing are handled.

**Recommendation**: Add one shared helper for "get ProxyPilot key from gopass, otherwise parse the local config" and reuse it across AI-agent states.

**Why here**: These states are tightly related and already share operational assumptions. Consolidating the fallback logic reduces drift and makes future credential-path changes much safer.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- render affected states and confirm the fallback command text is unchanged in behavior

---

### REC-004: Move shared Telegram allowlist constants into declarative data

**Scope**: `states/telethon_bridge.sls`, new `states/data/*.yaml` entry

**Problem**: The same hardcoded Telegram UID constants are repeated inline across multiple states.

**Recommendation**: Move these constants to a dedicated data file or an existing relevant YAML file and consume them via `import_yaml`.

**Why here**: The repository already prefers structured data for package sets, services, feature matrices, and model allowlists. Repeated IDs are configuration data, not logic.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- confirm both rendered configs still carry the same allowlist values

---

### REC-005: Make `user_services.sls` more data-driven for feature-tagged unit groups

**Scope**: `states/user_services.sls`, `states/data/user_services.yaml`

**Problem**: `user_services.sls` keeps several parallel hardcoded lists such as `mail_unit_ids`, `mail_enable`, `mail_timers`, and `vdirsyncer_*`, while the units themselves already live in YAML.

**Recommendation**: Extend `states/data/user_services.yaml` with optional feature tags like `mail` or `vdirsyncer`, then filter from data rather than maintaining separate Jinja lists in the state file.

**Why here**: This reduces list drift without moving core logic out of the SLS file. It is a repository-native use of declarative YAML, not an attempt to genericize everything.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- `just render-matrix`
- compare rendered enable/disable lists before and after

**Status**: done on feature branch `071-salt-refactor-program`

---

### REC-013: Route `video_ai.sls` downloads through a shared Hugging Face macro

**Scope**: `states/video_ai.sls`, `states/_macros_install.jinja`, `states/llama_embed.sls`

**Problem**: `video_ai.sls` duplicates several raw Hugging Face download blocks, which risks drift in retry, cache, and idempotency behavior.

**Recommendation**: Add a narrow Hugging Face helper over `http_file` and use it for `video_ai` model artifacts.

**Why here**: The repository already has a stable `http_file` abstraction. A tiny provider-specific wrapper preserves the macro-first rule without inventing a broader download DSL.

**Performance impact**: `neutral`

**Validation**:

- `just validate`
- render `video_ai` and confirm download state IDs and `creates` targets remain stable

**Status**: done on feature branch `071-salt-refactor-program`

---

### REC-006: Keep state-local recommendation IDs and rationale in the report, not in code comments

**Scope**: future follow-up refactor work across `states/*.sls`

**Problem**: Refactoring discussions often leak into code as explanatory comments or temporary labels that then stay forever.

**Recommendation**: Keep the rationale in this report and in future feature specs/tasks. Only add code comments when they explain non-obvious runtime behavior such as self-mutating configs or socket activation.

**Why here**: The constitution explicitly discourages unnecessary comment churn. This repository already uses comments mostly for high-value operational context.

**Performance impact**: `neutral`

**Validation**:

- review future follow-up diffs for unnecessary comment growth

## Requires Validation

### REC-007: Extract the repeated hyprpm command pattern behind a narrow helper

**Scope**: `states/desktop.sls`, optionally `states/_macros_service.jinja`

**Problem**: The Hyprland plugin flow repeats the same environment export, runtime-dir guard, retry block, and signature handling across multiple `cmd.run` states.

**Recommendation**: Consider a narrow helper for `hyprpm add/enable` operations, but only if it preserves the current readability of each state's `unless` and `require` logic.

**Why here**: There is real repetition, but this area is operationally fragile and already well-commented. A helper could help, but it can also hide the exact shell behavior.

**Performance impact**: `uncertain`

**Validation**:

- `just validate`
- run the affected Hyprland-related state in dry-run and compare rendered commands
- confirm no guard semantics changed

---

### REC-008: Consolidate NanoClaw clone/install/build/version flow

**Scope**: `states/nanoclaw.sls`

**Problem**: NanoClaw currently uses four separate command states for clone, install, build, and version pinning. The flow is correct but spread across multiple steps with repeated retry/build behavior.

**Recommendation**: Consider reducing the flow to a more compact versioned install pattern, but only if the resulting state remains debuggable and keeps each phase's guard behavior obvious.

**Why here**: This state is more procedural than most of the repo and stands out from the otherwise macro-first style.

**Performance impact**: `uncertain`

**Validation**:

- `just validate`
- run an idempotent dry-run on the feature-enabled host
- compare whether no-op behavior still skips clone/build/install correctly

---

### REC-009: Introduce a helper for "config file + reload/restart companion"

**Scope**: `states/network.sls`, `states/monitoring_loki.sls`, possibly `states/_macros_service.jinja`

**Problem**: Some patterns combine `file.managed` with a nearby reload/restart action, but each site expresses the pattern slightly differently.

**Recommendation**: Consider a tiny helper for the exact two-state pattern only when the reload behavior is truly identical. Do not force unlike cases into one macro.

**Why here**: The repository already has helpers like `ensure_running`, `unit_override`, and `user_service_file`. A narrow addition could reduce boilerplate in the right cases.

**Performance impact**: `uncertain`

**Validation**:

- `just validate`
- compare resultant requisites and `onchanges` wiring for each migrated site

## Avoid For Now

### REC-010: Do not replace the explicit feature-gated include list with a meta-generated loop

**Scope**: `states/system_description.sls`

**Problem**: The include list is visibly repetitive, which makes it tempting to generate it from a data table.

**Recommendation**: Do not convert the include graph into a Jinja loop over YAML metadata.

**Why here**: The current include file is one of the fastest ways to audit the highstate topology. A loop would save lines but make the compile path less explicit and harder to debug.

**Performance impact**: `negative`

**Validation**: Not recommended for implementation.

---

### REC-011: Do not force all custom service blocks into generic YAML schemas

**Scope**: `states/services.sls`, `states/network.sls`, `states/desktop.sls`, `states/data/*.yaml`

**Problem**: Once some simple services become data-driven, it is tempting to encode every custom service in YAML.

**Recommendation**: Stop at clearly uniform patterns like `simple_service`. Keep Samba, Transmission, Hyprpm, and similar blocks inline when they carry bespoke dependency or operational logic.

**Why here**: The constitution prefers minimal change and rejects abstraction for one-off operations. Over-generalizing service logic would move complexity from readable Salt into harder-to-debug schemas.

**Performance impact**: `negative`

**Validation**: Not recommended for implementation.

---

### REC-012: Do not macro-ize every `file.absent` legacy cleanup block

**Scope**: `states/dns.sls`, `states/network.sls`, `states/services.sls`, `states/monitoring_loki.sls`, `states/kanata.sls`, `states/installers.sls`

**Problem**: Several states contain one-shot legacy cleanup blocks, which can look like easy macro candidates.

**Recommendation**: Do not introduce a generic cleanup macro unless a future pass finds a materially larger repeated pattern than today's simple one-line `file.absent` usage.

**Why here**: These cleanups are explicit, cheap to read, and often semantically tied to a single state. Abstracting them now would add indirection for little gain.

**Performance impact**: `negative`

**Validation**: Not recommended for implementation.

## Keep As-Is

### KEEP-001: Preserve the thin `_imports.jinja` proxy

**Scope**: `states/_imports.jinja`

**Current pattern**: `_imports.jinja` re-exports shared values from `_macros_common.jinja` without adding business logic.

**Why it is correct**: It keeps state files readable and provides a single import surface without hiding where data comes from.

**Risk of changing it**: Pushing more logic into `_imports.jinja` would turn a clean proxy into a hidden control layer.

**Performance impact of keeping it**: `positive`

---

### KEEP-002: Preserve the explicit split between simple data-driven services and custom inline services

**Scope**: `states/services.sls`, `states/data/services.yaml`

**Current pattern**: Uniform services use the `simple_service` path, while Samba, Transmission, DuckDNS, and Bitcoind stay inline.

**Why it is correct**: This is exactly the right boundary between data-driven and bespoke logic in this repository.

**Risk of changing it**: Over-generalization would make complex services harder to reason about and easier to break.

**Performance impact of keeping it**: `positive`

---

### KEEP-003: Preserve `replace: False` seed-only deployment for self-mutating configs

**Scope**: `states/nanoclaw.sls`

**Current pattern**: Salt seeds initial config files and then avoids fighting tools that rewrite their own state on startup.

**Why it is correct**: This is already aligned with the constitution's self-modifying config rule and prevents noisy no-op applies.

**Risk of changing it**: Switching these files to always-replace semantics would create churn and could wipe runtime-managed values.

**Performance impact of keeping it**: `positive`

---

### KEEP-004: Preserve the conditional skip for Promtail when Loki is disabled

**Scope**: `states/monitoring_loki.sls`

**Current pattern**: Promtail is gated on both `promtail` and `loki`.

**Why it is correct**: This avoids a class of runtime log spam and keeps the monitoring graph coherent.

**Risk of changing it**: Reintroducing Promtail without Loki would restore a known noisy failure mode.

**Performance impact of keeping it**: `positive`

## Adoption Order

Implement in this order:

1. `REC-001`
2. `REC-002`
3. `REC-003`
4. `REC-004`
5. `REC-005`
6. review whether `REC-007` to `REC-009` are still worth doing after the safe-now items land

Do not schedule `REC-010` to `REC-012` unless repository constraints change.

## Validation Checklist For Follow-Up Refactors

For every adopted recommendation:

```bash
just validate
just render-matrix
```

If a change touches include structure, render branching, or command sequencing, also capture timing evidence from a recent apply log:

```bash
just profile
```
