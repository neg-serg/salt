# Implementation Plan: Salt Package Management with Minimal Dependency Coverage

**Branch**: `008-salt-pkg-management` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-salt-pkg-management/spec.md`

## Summary

Move package installation from an ad-hoc "managed outside Salt" approach to a declarative, data-driven model. An analysis script captures the current system's explicitly-installed packages (`pacman -Qqe`) into a categorized YAML file (`states/data/packages.yaml`), excluding packages already managed by domain-specific Salt states. A new `packages.sls` state consumes this file and installs all listed packages idempotently using existing macros. An optional reduction pass identifies redundant explicit packages (those already pulled as dependencies) for human review. A drift detection script reports packages installed outside the declared set.

## Technical Context

**Language/Version**: Jinja2/YAML (Salt states), Zsh (analysis + drift scripts)
**Primary Dependencies**: Salt (masterless), pacman, paru, ripgrep (for idempotency guards)
**Storage**: `states/data/packages.yaml` (categorized YAML consumed via `import_yaml`)
**Testing**: `just` (runs `salt-call state.apply system_description test=True`)
**Target Platform**: CachyOS (Arch-based) workstation
**Project Type**: Configuration management (Salt states + utility scripts)
**Performance Goals**: Salt apply with all packages present should add <30s to total apply time
**Constraints**: Must integrate with existing macro system; no new abstractions; coexist with domain-specific states
**Scale/Scope**: ~500-800 packages in the YAML file, 34 existing state modules, single workstation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | PASS | `pacman_install` macro has built-in `unless:` guard. Analysis script is one-shot (manual invocation). Drift script is read-only. |
| II. Network Resilience | PASS | `pacman_install`/`paru_install` macros include retry logic. New `packages.sls` uses macros exclusively. |
| III. Secrets Isolation | PASS | No secrets involved — package names are public data. |
| IV. Macro-First | PASS | `packages.sls` uses `pacman_install` and `paru_install` macros for all installs. No inline `cmd.run` for package management. |
| V. Minimal Change | PASS | Single new state file + single data file + two utility scripts. No refactoring of existing states. |
| VI. Convention Adherence | PASS | State IDs follow `target_descriptor` pattern. Scripts in `scripts/` use `#!/usr/bin/env zsh`. Data file follows `states/data/*.yaml` pattern. |
| VII. Verification Gate | PASS | `just` will be run after implementation. |
| VIII. CI Gate | PASS | CI will validate the new state renders cleanly. |

No violations. Complexity Tracking not needed.

## Project Structure

### Documentation (this feature)

```text
specs/008-salt-pkg-management/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
states/
├── data/
│   └── packages.yaml          # NEW: categorized package declarations
├── packages.sls               # NEW: state consuming packages.yaml
└── system_description.sls     # MODIFIED: add 'packages' to include list

scripts/
├── pkg-snapshot.zsh           # NEW: analysis tool (captures pacman -Qqe → packages.yaml)
└── pkg-drift.zsh              # NEW: drift detection (compares declared vs actual)
```

**Structure Decision**: Follows the established `states/data/*.yaml` → `states/*.sls` pattern. Analysis and drift scripts go in `scripts/` alongside existing utility scripts. No new directories needed.
