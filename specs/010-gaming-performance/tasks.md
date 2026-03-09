# Tasks: Gaming Performance Optimization

**Input**: Design documents from `/specs/010-gaming-performance/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Not requested in feature specification. No test tasks included.

**Organization**: Tasks grouped by user story. All stories are independent — no cross-story dependencies.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: No dedicated setup needed — project structure exists, all dependencies installed via existing `steam.sls`

_(No tasks — proceed to Phase 2)_

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No blocking prerequisites — all user stories produce independent config files that can be created in any order. GameMode, MangoHud, and gaming packages are already installed by `steam.sls`.

_(No tasks — proceed to user stories)_

**Checkpoint**: Foundation ready — existing `steam.sls` provides all packages. User story implementation can begin.

---

## Phase 3: User Story 1 — Automatic Performance Mode During Gaming (Priority: P1) 🎯 MVP

**Goal**: When a game launches, GameMode automatically switches CPU governor to `performance`, sets AMD GPU to high-performance DPM, elevates I/O priority, and applies soft realtime scheduling. All changes revert on game exit.

**Independent Test**: Run `gamemoded -t` to validate config. Then `gamemoderun glxgears`, check `gamemoded -s` shows active, verify CPU governor is `performance` via `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`. Kill glxgears, confirm governor reverts to `powersave`.

### Implementation for User Story 1

- [x] T001 [P] [US1] Create GameMode configuration in `states/configs/gamemode.ini` — INI file with `[general]` section (desiredgov=performance, defaultgov=powersave, softrealtime=auto, renice=10, ioprio=0, inhibit_screensaver=1, reaper_freq=5), `[gpu]` section (apply_gpu_optimisations=accept-responsibility, gpu_device=0, amd_performance_level=high), and `[custom]` section (start=/usr/local/bin/gamemode-start.sh, end=/usr/local/bin/gamemode-end.sh). See data-model.md for full key/value reference.

- [x] T002 [P] [US1] Create GameMode start hook script in `states/scripts/gamemode-start.sh` — Bash script (#!/bin/bash, set -euo pipefail) that exports game-scoped environment variables: `RADV_PERFTEST=gpl,nggc,sam` and any other AMD RADV flags that affect all Vulkan applications. These variables are scoped to game processes only (not set globally) per FR-003 hybrid approach. Script should be idempotent and log to journal via `logger -t gamemode-start`.

- [x] T003 [P] [US1] Create GameMode end hook script in `states/scripts/gamemode-end.sh` — Bash script that reverts any changes made by gamemode-start.sh. Since environment variables are process-scoped (die with the process), this script primarily serves as a logging endpoint (`logger -t gamemode-end`) and placeholder for any future revert actions. Keep minimal per constitution principle V.

- [x] T004 [US1] Add Salt states to `states/steam.sls` for deploying GameMode config and scripts — Add three `file.managed` states inside the existing `{% if host.features.steam %}` block: (1) `gamemode_config` deploying `salt://configs/gamemode.ini` to `/etc/gamemode.ini` mode 0644, (2) `gamemode_start_script` deploying `salt://scripts/gamemode-start.sh` to `/usr/local/bin/gamemode-start.sh` mode 0755, (3) `gamemode_end_script` deploying `salt://scripts/gamemode-end.sh` to `/usr/local/bin/gamemode-end.sh` mode 0755. All three require `cmd: steam_pkg`. Use `target_descriptor` state ID naming per convention.

**Checkpoint**: After T001–T004, GameMode is fully configured. Running `sudo salt-call state.apply steam` deploys config + scripts. `gamemoded -t` validates. Games automatically get CPU/GPU/IO optimization.

---

## Phase 4: User Story 2 — Proton/DXVK Environment Optimization (Priority: P2)

**Goal**: Globally-safe environment variables for DXVK async shaders, FSR upscaling, Mesa threaded GL, and shader cache are set session-wide so all Proton/Wine games benefit automatically.

**Independent Test**: After `chezmoi apply`, log out and back in (or `systemctl --user import-environment`). Run `env | grep -E 'DXVK|WINE|mesa|MESA|MANGOHUD'` and verify all 7 variables from data-model.md are set. Launch a Proton game and confirm shader compilation stutter is reduced.

### Implementation for User Story 2

- [x] T005 [US2] Create gaming environment variables file in `dotfiles/dot_config/environment.d/20-gaming.conf` — chezmoi-managed file (not a template, no secrets). Set variables per data-model.md Environment Profile entity: `DXVK_ASYNC=1`, `DXVK_STATE_CACHE=1`, `WINE_FULLSCREEN_FSR=1`, `WINE_FULLSCREEN_FSR_STRENGTH=2`, `mesa_glthread=true`, `MESA_SHADER_CACHE_MAX_SIZE=10G`, `MANGOHUD=0`. Add comments explaining each variable's scope (which software reads it) for maintainability.

**Checkpoint**: After T005, Proton games get async shaders and FSR by default. This works independently of GameMode (US1) — even without gamemode.ini, these env vars improve Proton performance.

---

## Phase 5: User Story 3 — Kernel and System-Level Latency Reduction (Priority: P3)

**Goal**: Add two sysctl parameters that reduce latency spikes during gaming without affecting desktop performance.

**Independent Test**: After `sudo salt-call state.apply sysctl`, verify: `sysctl vm.compaction_proactiveness` returns 0, `sysctl kernel.sched_cfs_bandwidth_slice_us` returns 3000. Run a demanding game and observe frame time graph in mangohud — spikes should be less frequent.

### Implementation for User Story 3

- [x] T006 [US3] Append gaming sysctl parameters to `states/configs/sysctl-custom.conf` — Add a `# === Gaming latency tuning ===` comment section at the end of the existing file, followed by: `vm.compaction_proactiveness = 0` (disable proactive memory compaction to reduce latency spikes) and `kernel.sched_cfs_bandwidth_slice_us = 3000` (finer CFS bandwidth slicing for gaming threads). Do NOT modify existing parameters. The existing `sysctl_apply` state in `sysctl.sls` already runs `sysctl --system` on changes via `onchanges`, so no state file modification needed.

**Checkpoint**: After T006, kernel latency tuning is applied on next Salt apply. This is fully independent of US1 and US2.

---

## Phase 6: User Story 4 — GPU Power and Display Optimization (Priority: P3)

**Goal**: AMD GPU power profiles activate during gaming (handled by GameMode config from US1). VRR (variable refresh rate) is enabled in the display compositor.

**Independent Test**: During gameplay with GameMode active, check `cat /sys/class/drm/card*/device/power_dpm_force_performance_level` shows `high`. Verify VRR is active via `hyprctl monitors` (shows `vrr: 1`).

**Note**: GPU power profile switching is already implemented in T001 (`gamemode.ini` `[gpu]` section). This phase handles the VRR/display configuration only.

### Implementation for User Story 4

- [x] T007 [US4] Verify and configure VRR in Hyprland config — Check `dotfiles/dot_config/hypr/hyprland.conf` (or equivalent Hyprland config managed by chezmoi) for `misc:vrr` setting. If VRR is not already enabled, add `misc:vrr = 1` (or `2` for fullscreen-only). If already configured, document in this task that no change is needed. VRR enables FreeSync/Adaptive Sync for the 3840x2160@240Hz display.

**Checkpoint**: After T007, VRR is confirmed active. Combined with US1's GameMode GPU config, full GPU optimization is in place.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: MangoHud overlay config (serves all user stories for performance monitoring) and final verification.

- [x] T008 [P] Create MangoHud configuration in `dotfiles/dot_config/MangoHud/MangoHud.conf` — chezmoi-managed file. Set `no_display=1` (hidden by default), `toggle_hud=Shift_R+F12`, `toggle_fps_limit=Shift_R+F11`. Enable metrics: fps, frametime, cpu_stats, gpu_stats, cpu_temp, gpu_temp, gpu_power, ram, vram, vulkan_driver, wine, gamemode. See data-model.md MangoHud Configuration entity for full key list. Add position and style settings for readable overlay at 4K resolution (e.g., `font_size=24`, `position=top-left`).

- [x] T009 Run `just` to verify Salt renders cleanly with all changes per constitution principle VII (Verification Gate)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Skipped — no setup needed
- **Foundational (Phase 2)**: Skipped — no blocking prerequisites
- **User Stories (Phase 3–6)**: All independent, can start immediately
- **Polish (Phase 7)**: T008 (MangoHud) can run in parallel with any story. T009 (verification) must run last.

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies — creates GameMode config from scratch
- **User Story 2 (P2)**: No dependencies — creates environment.d file from scratch
- **User Story 3 (P3)**: No dependencies — appends to existing sysctl config
- **User Story 4 (P3)**: Soft dependency on US1 (GPU power profile in gamemode.ini), but VRR config (T007) is independent

### Within Each User Story

- T001, T002, T003 can run in parallel (different files)
- T004 depends on T001, T002, T003 (Salt states reference those files)
- T005, T006, T007, T008 are all independent of each other

### Parallel Opportunities

```
Parallel group 1 (can all run simultaneously):
  T001 — gamemode.ini
  T002 — gamemode-start.sh
  T003 — gamemode-end.sh
  T005 — 20-gaming.conf
  T006 — sysctl-custom.conf append
  T007 — VRR check/config
  T008 — MangoHud.conf

Sequential (after parallel group 1):
  T004 — steam.sls states (needs T001, T002, T003)
  T009 — verification (needs all tasks)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete T001, T002, T003 (parallel — GameMode config + scripts)
2. Complete T004 (Salt states for deployment)
3. **STOP and VALIDATE**: `gamemoded -t`, test with a game
4. This alone delivers ~70% of the performance improvement (CPU governor + GPU + I/O + scheduling)

### Incremental Delivery

1. US1 (T001–T004) → GameMode optimization → Test → **MVP deployed**
2. US2 (T005) → Proton env vars → Test → Shader stutter eliminated
3. US3 (T006) → Sysctl tuning → Test → Latency spikes reduced
4. US4 (T007) → VRR verified → Test → Display optimization confirmed
5. Polish (T008–T009) → MangoHud + verification → **Feature complete**

Each increment adds value without breaking previous stories.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No test tasks generated (not requested in spec)
- T007 (VRR) may result in "no change needed" if already configured — this is acceptable
- Commit after each task or logical group using `[steam]` scope for Salt changes, `[dotfiles]` for chezmoi
- All new files follow constitution conventions: configs ≥10 lines in `configs/`, scripts in `scripts/`, state IDs use `target_descriptor` pattern
