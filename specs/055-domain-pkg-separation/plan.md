# Implementation Plan: Domain Package Separation

**Branch**: `055-domain-pkg-separation` | **Date**: 2026-03-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/055-domain-pkg-separation/spec.md`

## Summary

Move domain-specific package categories (`audio`, `fonts`, `gaming`, `desktop`) out of `states/data/packages.yaml` and `states/packages.sls` into their respective domain states. Add a lint script to enforce zero overlap between `packages.yaml` and domain state package lists. The migration is asymmetric: `gaming` is already empty, `audio`/`fonts` have 1 package each, while `desktop` has 19 packages to relocate.

## Technical Context

**Language/Version**: Jinja2/YAML (Salt 3006.x state files), Python 3.12+ (lint script)
**Primary Dependencies**: Salt (masterless), existing `_macros_pkg.jinja` macros, PyYAML
**Storage**: YAML data files on disk (`states/data/*.yaml`)
**Testing**: `just validate` (Salt render), `just apply` (full apply), `just lint` (linters), pytest (unit tests)
**Target Platform**: CachyOS (Arch-based) workstation
**Project Type**: Configuration management (Salt states)
**Performance Goals**: N/A — compile-time migration, no runtime impact
**Constraints**: Zero package regressions (every package currently installed must still be installed after migration)
**Scale/Scope**: 4 categories to remove, ~21 packages to relocate, 4 domain states to update, 1 new lint script, 1 new data file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | PASS | No new `cmd.run` states; relocated packages use existing macros with guards |
| II. Network Resilience | PASS | Relocated packages use `pacman_install` macro which enforces retry/parallel |
| III. Secrets Isolation | PASS | No secrets involved in package declarations |
| IV. Macro-First | PASS | All package installs use `pacman_install`/`paru_install` macros |
| V. Minimal Change | PASS | Migration moves data only; no new abstractions or speculative features |
| VI. Convention Adherence | PASS | All packages retain inline comments; state IDs follow `target_descriptor` pattern |
| VII. Verification Gate | PASS | `just validate` + `just apply` required before completion |
| VIII. CI Gate | PASS | Lint script added to `just lint`; CI runs lint |

**Post-Phase 1 Re-check**: All principles still satisfied. The new lint script (`scripts/lint-pkg-overlap.py`) follows existing lint script patterns (Python 3.12+, PyYAML, exit code conventions).

## Project Structure

### Documentation (this feature)

```text
specs/055-domain-pkg-separation/
├── plan.md              # This file
├── research.md          # Phase 0: migration inventory
├── data-model.md        # Phase 1: package ownership model
├── quickstart.md        # Phase 1: implementation quickstart
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
states/
├── data/
│   ├── packages.yaml          # MODIFIED: remove audio/fonts/gaming/desktop categories
│   ├── desktop.yaml           # MODIFIED: add relocated desktop packages
│   └── fonts.yaml             # MODIFIED: add noto-fonts-cjk
├── packages.sls               # MODIFIED: update category loop
├── audio.sls                  # MODIFIED: add pipewire to package list
├── desktop.sls                # MODIFIED: install packages from expanded desktop.yaml
├── fonts.sls                  # MODIFIED: ensure noto-fonts-cjk in pacman list
└── steam.sls                  # NO CHANGE: gaming category already empty

scripts/
└── lint-pkg-overlap.py        # NEW: zero-overlap lint check

tests/
└── unit/
    └── test_pkg_overlap.py    # NEW: unit tests for overlap detection
```

**Structure Decision**: No new directories needed. Changes are data migrations within existing files plus one new lint script following the established `scripts/lint-*.py` pattern.
