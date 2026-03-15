# Tasks: Quickshell Album Color Cache

**Input**: Design documents from `/specs/032-qs-album-color-cache/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md

**Tests**: Manual verification only (no automated tests requested).

**Organization**: Tasks grouped by user story. US1 and US2 share Phase 2 (same code delivers both — cache skip and fresh extraction are two sides of the same logic).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Foundational — Accent Infrastructure in MusicManager

**Purpose**: Add centralized accent color extraction with URL-based caching and change detection to the MusicManager singleton. This is the core change that enables all three user stories.

**⚠ CRITICAL**: No consumer changes can begin until this phase is complete.

- [x] T001 [US1] Add accent state properties (`accentColor`, `accentReady`, `_lastSampledUrl`, `_accentCache`) to `dotfiles/dot_config/quickshell/Services/MusicManager.qml`
- [x] T002 [US1] Add hidden `Image` element (sampler resolution, source bound to `coverUrl`) and `Canvas` element with `AccentSampler.sampleAccent()` paint handler in `dotfiles/dot_config/quickshell/Services/MusicManager.qml`
- [x] T003 [US1] Add debounce `Timer` (interval: `Theme.mediaArtDebounceMs`) and retry `Timer` (interval: `Theme.mediaAccentRetryMs`, max: `Theme.mediaAccentRetryMax`) in `dotfiles/dot_config/quickshell/Services/MusicManager.qml`
- [x] T004 [US1] Implement `onCoverUrlChanged` handler with three-way branch: same URL → skip, cache hit → restore + set ready, miss → debounced sampling in `dotfiles/dot_config/quickshell/Services/MusicManager.qml`
- [x] T005 [US2] Implement Canvas `onPaint` handler: draw hidden Image, call `AccentSampler.sampleAccent()` with explicit Theme threshold opts, update `accentColor`/`accentReady`/`_accentCache` on result or fallback in `dotfiles/dot_config/quickshell/Services/MusicManager.qml`
- [x] T006 [US2] Handle edge cases in `onCoverUrlChanged`: empty/null URL → reset to `Theme.accentPrimary` with `accentReady = false`; Image not ready on first paint → retry timer kicks in, same as current behavior in `dotfiles/dot_config/quickshell/Services/MusicManager.qml`

**Checkpoint**: MusicManager now exposes `accentColor` and `accentReady`. Consumers still have their own local sampling — both systems run in parallel (safe, just redundant). Verify: `console.log` in MusicManager's `onPaint` fires on album change but not on same-album track skip.

---

## Phase 2: User Story 1+2 — Simplify Bar Media Module (P1)

**Goal**: Remove redundant accent sampling from the bar media module. Bind to `MusicManager.accentColor` instead.

**Independent Test**: Play album, skip tracks — bar accent color remains stable (US1). Switch album — bar accent color updates (US2). No flicker in either case.

### Implementation

- [x] T007 [US1] Replace `property color mediaAccent: Theme.accentPrimary` with `property color mediaAccent: MusicManager.accentColor` in `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T008 [US1] Replace `property bool accentReady: false` with `property bool accentReady: MusicManager.accentReady` in `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T009 [US1] Remove `property var _accentCache`, `_requestSample()` function, `_tryRestoreCachedAccent()` function, and `property int _accentRetryCount` from `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T010 [US1] Remove `Canvas { id: colorSampler }` element (lines ~202-232) from `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T011 [US1] Remove `Timer { id: sampleDebounce }` and `Timer { id: accentRetry }` from `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T012 [US1] Remove accent-related `Connections` block (`onCoverUrlChanged`, `onTrackAlbumChanged` handlers) from `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T013 [US1] Remove `Component.onCompleted: { _requestSample() }` and `onVisibleChanged: { if (visible) _requestSample() }` from `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T014 [US1] Remove `AccentSampler.js` import (no longer used) from `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`
- [x] T015 [US2] Verify `property int accentVersion` still increments on `onMediaAccentChanged` (now driven by MusicManager binding) — keep existing `onMediaAccentChanged: { accentVersion++ }` in `dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`

**Checkpoint**: Bar media module uses centralized accent. All downstream bindings (spectrum bar color, rich text CSS, icon highlight) work via existing `mediaAccent` alias. No local Canvas or timers remain.

---

## Phase 3: User Story 3 — Simplify Side Panel Music Widget (P2)

**Goal**: Remove redundant accent sampling from the side panel music widget. Share the same cached accent color from MusicManager.

**Independent Test**: Open side panel while music plays — accent color appears instantly (no independent extraction). Bar and panel show identical accent color.

### Implementation

- [x] T016 [P] [US3] Replace `property color musicAccent: Theme.accentPrimary` with `property color musicAccent: MusicManager.accentColor` in `detailsCol` within `dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`
- [x] T017 [P] [US3] Replace `property bool musicAccentReady: false` with `property bool musicAccentReady: MusicManager.accentReady` in `detailsCol` within `dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`
- [x] T018 [US3] Remove `property var _accentCache`, `property int _accentRetryCount` from `detailsCol` in `dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`
- [x] T019 [US3] Remove `Canvas { id: accentSampler }` element (lines ~283-320) from `dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`
- [x] T020 [US3] Remove `Timer { id: musicAccentRetry }` from `detailsCol` in `dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`
- [x] T021 [US3] Remove accent-sampling trigger from `albumArt.onStatusChanged` handler (lines ~257-273) — keep only the Image status handling, remove cache restore + `accentSampler.requestPaint()` + `musicAccentRetry.restart()` in `dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`
- [x] T022 [US3] Remove `AccentSampler.js` import (no longer used) from `dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`

**Checkpoint**: Both bar and side panel consume `MusicManager.accentColor`. Zero duplicate Canvas samplers remain. Accent color is shared between components.

---

## Phase 4: Polish & Verification

**Purpose**: End-to-end validation and cleanup.

- [ ] T023 Manual verification: play album with 3+ tracks, skip within same album — accent color stays stable, no flicker (SC-001, SC-004)
- [ ] T024 Manual verification: switch to different album — accent color updates within debounce+retry budget (SC-002)
- [ ] T025 Manual verification: open side panel while bar shows accent — panel shows identical color instantly (SC-003)
- [ ] T026 Manual verification: play track with no cover art — falls back to theme default color (FR-005, edge case)
- [ ] T027 Manual verification: rapid track skipping across multiple albums — debounce coalesces, only final album's color extracted (edge case)
- [x] T028 Run `just` to confirm Salt renders successfully (Constitution Principle VII)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Foundational)**: No dependencies — start immediately
- **Phase 2 (Bar simplification)**: Depends on Phase 1 completion
- **Phase 3 (Panel simplification)**: Depends on Phase 1 completion. Independent of Phase 2 (different file)
- **Phase 4 (Verification)**: Depends on Phase 2 + Phase 3 completion

### User Story Dependencies

- **US1 + US2 (P1)**: Delivered by Phase 1 (MusicManager) + Phase 2 (Media.qml). No cross-story dependencies
- **US3 (P2)**: Delivered by Phase 1 (MusicManager, shared) + Phase 3 (Music.qml). Independent of US1/US2 consumer changes

### Parallel Opportunities

- **Phase 2 + Phase 3**: Can run in parallel after Phase 1 (different files: `Media.qml` vs `Music.qml`)
- **T016 + T017**: Can run in parallel (independent property replacements)

---

## Parallel Example: Consumer Simplification

```
# After Phase 1 completes, launch both consumer simplifications together:
Task: "Simplify Media.qml — bind to MusicManager.accentColor" (Phase 2)
Task: "Simplify Music.qml — bind to MusicManager.accentColor" (Phase 3)
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2)

1. Complete Phase 1: MusicManager accent infrastructure
2. Complete Phase 2: Bar media module simplification
3. **STOP and VALIDATE**: Bar accent works correctly — skip on same album, update on new album
4. This alone delivers US1 + US2 for the primary visible component

### Incremental Delivery

1. Phase 1 → MusicManager has centralized accent (both systems run, old + new)
2. Phase 2 → Bar uses shared accent (US1 + US2 delivered for bar)
3. Phase 3 → Panel uses shared accent (US3 delivered — full dedup)
4. Phase 4 → Verify all acceptance scenarios

---

## Notes

- No automated tests — verification is manual (play music, observe colors)
- AccentSampler.js is unchanged — only *when* it's called changes, not *how*
- Local aliases (`mediaAccent: MusicManager.accentColor`) minimize diff in consumers — all downstream bindings (spectrum bars, rich text, icons) remain untouched
- Total scope: ~3 files modified, ~100 lines net change (remove more than add)
