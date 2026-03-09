# Implementation Plan: Chezmoi/Salt File Ownership Boundary

**Branch**: `007-chezmoi-salt-boundary` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-chezmoi-salt-boundary/spec.md`

## Summary

Eliminate 8 dual-written files by assigning all to Salt ownership (each has Salt-specific requirements: secrets, triggers, or non-XDG deploy paths). Add 5 floorp entries to `.chezmoiignore`, delete the redundant proxypilot chezmoi template, create a lint script to prevent regressions, and document the ownership policy in CLAUDE.md.

## Technical Context

**Language/Version**: Python 3.12+ (lint script), Jinja2/YAML (Salt states)
**Primary Dependencies**: Salt, chezmoi, ripgrep (for lint pattern matching)
**Storage**: Configuration files on disk
**Testing**: `just lint` (lint scripts), `just apply` (Salt render verification)
**Target Platform**: CachyOS (Arch-based Linux)
**Project Type**: Infrastructure/configuration management
**Performance Goals**: N/A (config management, not runtime)
**Constraints**: Minimal change (Constitution V); no new dependencies
**Scale/Scope**: 8 files to resolve, 1 new lint script (~60 lines), 5 files modified

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | PASS | No new `cmd.run` states introduced |
| II. Network Resilience | PASS | No network access needed |
| III. Secrets Isolation | PASS | No new secrets; existing gopass patterns preserved |
| IV. Macro-First | PASS | No new infrastructure patterns; existing macros unchanged |
| V. Minimal Change | PASS | Changes limited to ownership boundary fixes |
| VI. Convention Adherence | PASS | Lint script follows `scripts/lint-*.py` naming; commit style `[salt]` or `[dotfiles]` |
| VII. Verification Gate | PASS | `just` will be run after changes |
| VIII. CI Gate | PASS | New lint script added to `just lint` |

**Post-Phase 1 Re-check**: All gates still pass. No new architectural patterns introduced.

## Project Structure

### Documentation (this feature)

```text
specs/007-chezmoi-salt-boundary/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: ownership assignments & rationale
├── data-model.md        # Phase 1: entity model & state transitions
├── quickstart.md        # Phase 1: verification guide
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
dotfiles/
├── .chezmoiignore              # MODIFY: add 5 floorp entries
└── dot_config/
    ├── floorp/                  # KEEP: Salt sources via salt://dotfiles/
    │   ├── user.js
    │   ├── userChrome.css
    │   ├── userContent.css
    │   └── custom/
    │       ├── userChrome.css
    │       └── userContent.css
    └── proxypilot/
        └── config.yaml.tmpl    # DELETE: Salt has separate source

scripts/
└── lint-ownership.py           # CREATE: dual-write detection lint

Justfile                        # MODIFY: add lint-ownership to lint target
CLAUDE.md                       # MODIFY: add ownership policy section
```

**Structure Decision**: No new directories. Changes touch existing files across `dotfiles/`, `scripts/`, and project root. The lint script follows the established `scripts/lint-*.py` pattern.

## Detailed Change Plan

### Change 1: Update `.chezmoiignore` (FR-003)

Add 5 floorp entries with explanatory comment:

```
# Floorp browser: Salt deploys to ~/.floorp/<profile>/ (non-XDG path)
.config/floorp/user.js
.config/floorp/userChrome.css
.config/floorp/userContent.css
.config/floorp/custom/
```

**Rationale**: Chezmoi would deploy these to `~/.config/floorp/` which Floorp never reads. Salt deploys to `~/.floorp/<profile>/` using the `host.floorp_profile` grain. The `.config/floorp/custom/` directory entry covers both CSS files inside it.

### Change 2: Delete proxypilot chezmoi template (FR-007)

Delete `dotfiles/dot_config/proxypilot/config.yaml.tmpl` and its parent directory `dotfiles/dot_config/proxypilot/`.

**Rationale**: Salt uses a completely separate Jinja2 template at `states/configs/proxypilot.yaml.j2` with gopass fallback. The chezmoi template is a dead file (already in `.chezmoiignore`). Per clarification: delete entirely when Salt has separate source.

### Change 3: Create lint script (FR-009)

New file `scripts/lint-ownership.py` (~60 lines):

1. Parse all `.sls` files under `states/` for `salt://dotfiles/` URI references
2. Convert each URI to a chezmoi-relative path (e.g., `salt://dotfiles/dot_config/foo` → `.config/foo`)
3. Load `.chezmoiignore` entries (strip comments, empty lines)
4. For each Salt-referenced path, check if it (or a parent directory) is in `.chezmoiignore`
5. Report violations (Salt sources from `dotfiles/` but chezmoi not excluded) as errors
6. Exit 0 if no violations, exit 1 with error messages if any found

**Pattern**: Follows existing `scripts/lint-dotfiles.py` structure (standalone Python, no external deps beyond stdlib, clear error messages, exits non-zero on failure).

### Change 4: Update Justfile (FR-009)

Add `.venv/bin/python3 scripts/lint-ownership.py` to the `lint` recipe, after `lint-dotfiles.py`.

### Change 5: Document ownership policy in CLAUDE.md (FR-006)

Add a new subsection under **Conventions** with the ownership decision tree:

- Salt owns files requiring: (a) gopass secrets with fallback, (b) `watch`/`onchanges` triggers, (c) non-XDG deploy paths, (d) grain/pillar-conditional deployment
- Chezmoi owns purely declarative user dotfiles
- Files in `dotfiles/` that Salt sources via `salt://dotfiles/` MUST be listed in `.chezmoiignore`
- Files with Salt-separate sources (e.g., `salt://configs/`) MUST NOT exist in `dotfiles/`

## Ownership Assignment Table

| # | File | Owner | Reason | Action |
|---|------|-------|--------|--------|
| 1 | `mpd.conf` | Salt | `require` chain to service | None (already in `.chezmoiignore`) |
| 2 | `mpdas.service` | Salt | `user_service_file` macro | None (already in `.chezmoiignore`) |
| 3 | `proxypilot/config.yaml` | Salt | Secrets + gopass fallback | Delete chezmoi template |
| 4 | `floorp/user.js` | Salt | `onchanges` trigger + profile path | Add to `.chezmoiignore` |
| 5 | `floorp/userChrome.css` | Salt | Profile path deployment | Add to `.chezmoiignore` |
| 6 | `floorp/userContent.css` | Salt | Profile path deployment | Add to `.chezmoiignore` |
| 7 | `floorp/custom/userChrome.css` | Salt | Profile path deployment | Add to `.chezmoiignore` (via `custom/` dir) |
| 8 | `floorp/custom/userContent.css` | Salt | Profile path deployment | Add to `.chezmoiignore` (via `custom/` dir) |

## Complexity Tracking

No constitution violations. All changes are minimal and follow existing patterns.
