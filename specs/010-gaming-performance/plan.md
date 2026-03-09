# Implementation Plan: Gaming Performance Optimization

**Branch**: `010-gaming-performance` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/010-gaming-performance/spec.md`

## Summary

Configure GameMode, MangoHud, and gaming environment variables to automatically optimize CPU governor, GPU power profile, I/O priority, and Proton/DXVK rendering when games are launched. Extends existing `steam.sls` with config deployment; adds chezmoi dotfiles for MangoHud and environment variables. Minimal sysctl additions (2 parameters) since kernel is already gaming-tuned.

## Technical Context

**Language/Version**: Jinja2/YAML (Salt states), INI (GameMode/MangoHud configs), Bash (GameMode scripts)
**Primary Dependencies**: Salt (masterless), chezmoi, GameMode, MangoHud, DXVK, Mesa/RADV
**Storage**: Config files on disk
**Testing**: `gamemoded -t` (GameMode config validation), `just` (Salt render verification)
**Target Platform**: CachyOS (Arch-based), AMD CPU + AMD GPU (RADV), 3840x2160@240Hz
**Project Type**: System configuration (Salt states + chezmoi dotfiles)
**Performance Goals**: ≥10% FPS improvement, ≥15% frame time variance improvement, <1 frame shader stutter
**Constraints**: No security degradation, no desktop performance impact when not gaming
**Scale/Scope**: Single workstation (telfir), 5 new files, 2 modified files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | PASS | All new states use `file.managed` (inherently idempotent) or `cmd.run` with guards |
| II. Network Resilience | PASS | No network access needed — all configs are local file deployments |
| III. Secrets Isolation | PASS | No secrets involved in gaming configuration |
| IV. Macro-First | PASS | Using `file.managed` directly (no macro exists for INI config deployment; macros cover packages/downloads) |
| V. Minimal Change | PASS | Only adding what's needed: 5 new files, 2 appended parameters. No refactoring |
| VI. Convention Adherence | PASS | State IDs follow `target_descriptor` pattern; configs ≥10 lines in `configs/`; scripts in `scripts/`; chezmoi for user dotfiles |
| VII. Verification Gate | PASS | `just` will be run before completion |
| VIII. CI Gate | PASS | No CI changes needed; existing pipeline validates Salt rendering |

**Post-Phase 1 re-check**: All principles still pass. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/010-gaming-performance/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: entity definitions
├── quickstart.md        # Phase 1: implementation guide
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
states/
├── steam.sls                          # MODIFY: add gamemode config + script deployment
├── configs/
│   ├── gamemode.ini                   # NEW: GameMode configuration
│   └── sysctl-custom.conf            # MODIFY: append 2 gaming parameters
├── scripts/
│   ├── gamemode-start.sh             # NEW: GameMode start hook (RADV_PERFTEST, etc.)
│   └── gamemode-end.sh               # NEW: GameMode end hook (revert)

dotfiles/
├── dot_config/
│   ├── MangoHud/
│   │   └── MangoHud.conf             # NEW: MangoHud overlay config
│   └── environment.d/
│       └── 20-gaming.conf            # NEW: gaming environment variables
```

**Structure Decision**: No new state files — gaming domain stays in `steam.sls`. New configs go to `states/configs/` and `states/scripts/` per convention. User dotfiles go to chezmoi. This follows the existing pattern exactly.
