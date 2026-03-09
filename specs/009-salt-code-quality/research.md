# Research: Salt Code Quality Improvement

**Branch**: `009-salt-code-quality` | **Date**: 2026-03-09

## R1: Existing Lint Infrastructure

**Decision**: Extend existing `scripts/lint-jinja.py` instead of creating new `lint-salt.py`.

**Rationale**: `lint-jinja.py` (990 lines) already implements:
- Jinja2 syntax validation
- Duplicate state ID detection (renders all .sls with mock Salt context)
- State ID naming convention checks (`install_*`/`build_*` prefix enforcement)
- Require/watch/onchanges resolution (validates requisite targets exist)
- Dangling include detection
- Network resilience checks (`check_network_resilience` — detects missing retry/parallel on cmd.run with curl/git/pacman/paru/cargo/pip/npm)
- Bash syntax without `shell: /bin/bash` detection
- salt:// URI reference validation
- Systemd unit file verification via `systemd-analyze verify`
- Data file integrity (required keys, version cross-references)
- Host config validation (field types, allowed values, unknown keys)
- Unused import detection

**What's missing** (to add for FR-010/FR-011):
- Idempotency guard check: detect `cmd.run`/`cmd.script` without `creates:`, `unless:`, `onlyif:`, or `onchanges:`
- Inline suppression comments (`# salt-lint: disable=<rule>`)
- Promote network resilience warnings to errors (currently warnings only)

**Alternatives considered**:
- New `lint-salt.py`: rejected — would duplicate 80% of existing logic and require maintaining two rendering pipelines
- External tool (salt-lint): rejected — doesn't understand this project's macros/conventions

## R2: Parallel Concurrency Limit

**Decision**: Use existing `process_count_max: 16` in Salt minion config.

**Rationale**: `scripts/salt-apply.sh` already generates `.salt_runtime/minion` with `process_count_max: 16`. This limits concurrent parallel states to 16 processes — sufficient to prevent resource exhaustion during heavy builds while allowing broad parallelism for lightweight downloads.

**Alternatives considered**:
- Per-state concurrency groups: Salt doesn't support this natively; would require custom orchestration
- Lower limit (e.g., 4): too conservative for a workstation with 12+ cores
- No limit: risks OOM during concurrent cargo/makepkg builds

## R3: Version Tracking Pattern for Macros

**Decision**: Add optional `version` parameter to `npm_pkg` and `paru_install` using the existing `ver_stamp()` pattern.

**Rationale**: Other macros (`curl_bin`, `github_release_system`, etc.) already use version stamp files at `{{ ver_dir }}/{{ name }}` or `{{ sys_ver_dir }}/{{ name }}`. The stamp file contains the version string; the `unless` guard compares stamp content to the declared version. This pattern is proven and consistent across the codebase.

**Implementation**:
- `npm_pkg`: Add `version=''` parameter. When set, use `unless: test "$(cat {{ ver_dir }}/{{ name }} 2>/dev/null)" = "{{ version }}"` instead of `creates:`. After install, write stamp: `echo '{{ version }}' > {{ ver_dir }}/{{ name }}`.
- `paru_install`: Add `version=''` parameter. When set, use version stamp; otherwise keep existing `unless: rg -qx` guard. Note: paru packages update via system updates, so version tracking is mainly useful for pinned AUR packages.

**Alternatives considered**:
- Using `pacman -Q` for version check: slower (subprocess per package) and doesn't work for npm
- Embedding version in `creates:` path: breaks the stamp file pattern used elsewhere

## R4: Idempotency Guard Detection

**Decision**: Parse rendered YAML to detect `cmd.run`/`cmd.script` states missing all four guard types.

**Rationale**: The existing `check_network_resilience` function in `lint-jinja.py` already iterates rendered docs and inspects `cmd.run`/`cmd.script` directive lists. The idempotency check follows the same pattern — iterate directives looking for `creates`, `unless`, `onlyif`, or `onchanges` keys.

**Edge cases**:
- States triggered by `onchanges` from another state don't need their own guard (the trigger IS the guard). Must check rendered YAML for `onchanges` in the requisite list, not just directive list.
- States in `watch`/`onchanges_in` relationships: the watched state's change is the trigger.
- Suppression comment needed for rare cases where re-execution is intentional.

## R5: State File Split Strategy

**Decision**: Split 3 files based on codebase analysis.

| Current File | Lines | Split Into | Reasoning |
|---|---|---|---|
| `installers.sls` | 152 | `installers.sls` (data-driven tools) + `installers_mpv.sls` (mpv scripts) | mpv scripts are a distinct domain; main file stays data-driven |
| `services.sls` | 152 | `services.sls` (simple_service calls) + `services_bitcoind.sls` (custom build) | Bitcoind has a complex build pipeline that doesn't fit simple_service pattern |
| `monitoring.sls` | 124 | `monitoring.sls` (sysstat, vnstat, netdata) + `monitoring_loki.sls` (Loki, Promtail, Grafana) | Loki stack is a self-contained subsystem with its own health checks and inter-service dependencies |

**Alternatives considered**:
- More aggressive splitting (e.g., one file per tool): rejected per Constitution V (Minimal Change) — creates too many tiny files
- No splitting: rejected — 150+ line files mixing unrelated concerns violate FR-009

## R6: Data Extraction Candidates

**Decision**: Extract hardcoded lists from generic/multi-purpose state files only (per clarification).

**Candidates for extraction**:
- `desktop.sls`: Hyprland ecosystem packages (hyprpaper, hypridle, hyprlock, etc.) → `data/desktop.yaml`
- `installers.sls`: mpv script URLs → `data/installers.yaml` (extend existing)
- `monitoring.sls`: Loki/Promtail/Grafana URLs with version hashes → `data/versions.yaml` (extend existing)

**Keep inline** (domain-specific, ≤10 packages):
- `audio.sls`: PipeWire packages (3 items)
- `steam.sls`: Vulkan/gaming packages (part of domain logic)
- `dns.sls`: DNS resolver packages (part of service setup)
- `snapshots.sls`: Snapper packages (5 items)

## R7: Combined User Service Macro Feasibility

**Decision**: Create `user_service_with_unit()` macro that combines `user_service_file()` + `user_service_enable()`.

**Rationale**: 5+ state files repeat the pattern: deploy unit file → daemon-reload → enable service. A combined macro reduces this from 2 calls + explicit require wiring to 1 call.

**Parameters**: `name`, `filename`, `source` (optional), `services` (optional, defaults to [filename]), `start_now` (optional), `requires` (optional), `user`, `home`.

**Implementation**: Internally calls the existing two macros with proper require chain. No breaking changes — existing separate calls continue to work.

**Alternatives considered**:
- Replacing the two macros entirely: rejected — some callers (e.g., `user_services.sls`) loop over units then batch-enable, which needs separate calls
