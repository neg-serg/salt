# Implementation Plan: Quickshell Album Color Cache

**Branch**: `032-qs-album-color-cache` | **Date**: 2026-03-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/032-qs-album-color-cache/spec.md`

## Summary

Centralize album art accent color extraction into the `MusicManager` singleton, caching the result keyed by cover art URL. Skip extraction entirely when the cover URL hasn't changed. Remove duplicate Canvas samplers from `Media.qml` and `Music.qml` — both consume `MusicManager.accentColor` and `MusicManager.accentReady` via property bindings.

## Technical Context

**Language/Version**: QML 6 (Qt 6), JavaScript (ES5 helpers)
**Primary Dependencies**: Quickshell runtime, QtQuick, Quickshell.Services.Mpris
**Storage**: In-memory JS object (no persistence)
**Testing**: Manual (play album tracks, switch albums, observe color transitions)
**Target Platform**: CachyOS (Arch-based) Wayland desktop, Quickshell panel
**Project Type**: Desktop widget (Quickshell panel component)
**Performance Goals**: Zero Canvas pixel sampling on same-album track changes; instant color reuse
**Constraints**: Must not introduce visible flicker or delay; preserve all existing fallback behavior
**Scale/Scope**: 3 files modified, 1 file created, ~100 lines net change

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | N/A | No Salt states involved — pure QML/JS change |
| II. Network Resilience | N/A | No network access |
| III. Secrets Isolation | Pass | No secrets involved |
| IV. Macro-First | N/A | No Salt macros applicable |
| V. Minimal Change | Pass | Only touches accent sampling logic; no unrelated changes |
| VI. Convention Adherence | Pass | Files follow existing Quickshell structure conventions |
| VII. Verification Gate | Deferred | Will verify via `just` after implementation (Salt states unaffected, but validates render) |
| VIII. CI Gate | Deferred | Will validate post-implementation |

**Gate result**: PASS — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/032-qs-album-color-cache/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (affected files)

```text
dotfiles/dot_config/quickshell/
├── Services/
│   └── MusicManager.qml          # MODIFY: add accent properties, hidden Image+Canvas, cache logic
├── Helpers/
│   └── AccentSampler.js           # UNCHANGED (pure algorithm)
├── Bar/Modules/
│   └── Media.qml                  # MODIFY: remove local Canvas/cache, bind to MusicManager.accentColor
└── Widgets/SidePanel/
    └── Music.qml                  # MODIFY: remove local Canvas/cache, bind to MusicManager.accentColor
```

**Structure Decision**: No new directories. All changes are modifications to existing files within the established Quickshell component structure. The accent sampling logic moves from two leaf components into the existing `MusicManager` singleton.

## Design

### Approach: Centralize sampling in MusicManager

**Why MusicManager?** It's already a `pragma Singleton` that owns `coverUrl` and is imported by both consumers. Adding accent color here follows the existing pattern (playback state, metadata, cava values are all centralized here).

**Hidden Image + Canvas**: MusicManager will load the cover art into a small hidden `Image` (size: `Theme.mediaAccentSamplerPx` × `Theme.mediaAccentSamplerPx`) and sample it via a co-located `Canvas`. This avoids coupling to display Images in Media.qml/Music.qml.

### Property additions to MusicManager

```
property color accentColor: Theme.accentPrimary    // current accent (or fallback)
property bool  accentReady: false                   // true when extracted or cache-hit
property string _lastSampledUrl: ""                 // last URL that triggered extraction
property var   _accentCache: ({})                   // { url: color } map
```

### Cache-hit fast path

When `coverUrl` changes:
1. If `coverUrl === _lastSampledUrl` → do nothing (same album, color already set)
2. If `_accentCache[coverUrl]` exists → restore cached color, set `accentReady = true`, update `_lastSampledUrl`, skip Canvas sampling
3. Otherwise → set `_lastSampledUrl = coverUrl`, trigger debounced Canvas sampling

### Removal from consumers

**Media.qml** — remove:
- `property color mediaAccent` → replace with `MusicManager.accentColor`
- `property bool accentReady` → replace with `MusicManager.accentReady`
- `property var _accentCache` → deleted
- `Canvas { id: colorSampler }` → deleted
- `Timer { id: sampleDebounce }` → deleted
- `Timer { id: accentRetry }` → deleted
- `_requestSample()`, `_tryRestoreCachedAccent()` → deleted
- `Connections { onCoverUrlChanged, onTrackAlbumChanged }` (accent-related) → deleted
- Keep `property int accentVersion` and `onMediaAccentChanged` → rebind to `MusicManager.accentColor`

**Music.qml** — remove:
- `property color musicAccent` → replace with `MusicManager.accentColor`
- `property bool musicAccentReady` → replace with `MusicManager.accentReady`
- `property var _accentCache` → deleted
- `Canvas { id: accentSampler }` → deleted
- `Timer { id: musicAccentRetry }` → deleted
- `_accentRetryCount` → deleted

### Binding approach in consumers

To minimize diff size, introduce local aliases at the top of each consumer:

```qml
// Media.qml
property color mediaAccent: MusicManager.accentColor
property bool accentReady: MusicManager.accentReady
```

```qml
// Music.qml (in detailsCol)
property color musicAccent: MusicManager.accentColor
property bool musicAccentReady: MusicManager.accentReady
```

This preserves all downstream references (spectrum bar color, icon colors, rich text CSS) without touching them.

### Debounce and retry (moved to MusicManager)

- `Timer { id: accentDebounce; interval: Theme.mediaArtDebounceMs }` — gates `Canvas.requestPaint()`
- `Timer { id: accentRetry; interval: Theme.mediaAccentRetryMs }` — retries if Image not ready (max `Theme.mediaAccentRetryMax` attempts)
- Triggered by `onCoverUrlChanged` signal (MusicManager already emits this)

### Theme token usage

Sampling opts passed explicitly (matching Music.qml's current behavior which is more explicit than Media.qml's defaults):
```javascript
AccentSampler.sampleAccent(img, {
    satMin: Theme.mediaAccentSatMin,
    lumMin: Theme.mediaAccentLumMin,
    lumMax: Theme.mediaAccentLumMax,
    satRelax: Theme.mediaAccentSatRelax,
    lumRelaxMin: Theme.mediaAccentLumRelaxMin,
    lumRelaxMax: Theme.mediaAccentLumRelaxMax
})
```
