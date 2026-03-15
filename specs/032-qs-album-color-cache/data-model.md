# Data Model: Quickshell Album Color Cache

## Entities

### AccentState (in MusicManager singleton)

Properties added to the existing `MusicManager.qml` singleton:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `accentColor` | `color` | `Theme.accentPrimary` | Current accent color derived from album art, or theme fallback |
| `accentReady` | `bool` | `false` | Whether accent was successfully extracted or restored from cache |
| `_lastSampledUrl` | `string` | `""` | Cover URL that produced the current `accentColor`. Used for change detection |
| `_accentCache` | `var` (JS object) | `{}` | Map of `coverUrl → color`. In-memory, session-scoped |

### Internal elements (in MusicManager singleton)

| Element | Type | Purpose |
|---------|------|---------|
| `_accentImage` | `Image` | Hidden, 48×48. Loads `coverUrl` for sampling only |
| `_accentCanvas` | `Canvas` | Hidden, 48×48. Draws `_accentImage`, extracts pixel data |
| `_accentDebounce` | `Timer` | Interval: `Theme.mediaArtDebounceMs`. Coalesces rapid changes |
| `_accentRetry` | `Timer` | Interval: `Theme.mediaAccentRetryMs`. Retries if image not ready (max `Theme.mediaAccentRetryMax`) |
| `_accentRetryCount` | `int` | Counter for retry attempts |

## State Transitions

```
coverUrl changes
    │
    ├─ same as _lastSampledUrl? ──YES──→ [no action, accentColor unchanged]
    │
    └─ different ──→ _lastSampledUrl = coverUrl
                      │
                      ├─ _accentCache[url] exists? ──YES──→ accentColor = cached
                      │                                      accentReady = true
                      │                                      [still trigger sampling for freshness]
                      │
                      └─ no cache hit ──→ accentReady = false
                                          │
                                          └─ start _accentDebounce
                                              │
                                              └─ _accentCanvas.requestPaint()
                                                  │
                                                  ├─ sampleAccent() returns color ──→ accentColor = color
                                                  │                                    accentReady = true
                                                  │                                    _accentCache[url] = color
                                                  │
                                                  └─ returns null ──→ accentColor = Theme.accentPrimary
                                                                       accentReady = false
                                                                       _accentCache[url] = fallback
```

## Removed State (from consumers)

### Media.qml (Bar/Modules/Media.qml)

| Removed | Replaced by |
|---------|-------------|
| `property color mediaAccent` | Alias to `MusicManager.accentColor` |
| `property bool accentReady` | Alias to `MusicManager.accentReady` |
| `property var _accentCache` | Deleted (moved to MusicManager) |
| `Canvas { id: colorSampler }` | Deleted (moved to MusicManager) |
| `Timer { id: sampleDebounce }` | Deleted (moved to MusicManager) |
| `Timer { id: accentRetry }` | Deleted (moved to MusicManager) |
| `_requestSample()` | Deleted |
| `_tryRestoreCachedAccent()` | Deleted |
| `Connections { onCoverUrlChanged/onTrackAlbumChanged }` | Deleted (accent-related only) |

### Music.qml (Widgets/SidePanel/Music.qml)

| Removed | Replaced by |
|---------|-------------|
| `property color musicAccent` | Alias to `MusicManager.accentColor` |
| `property bool musicAccentReady` | Alias to `MusicManager.accentReady` |
| `property var _accentCache` | Deleted (moved to MusicManager) |
| `Canvas { id: accentSampler }` | Deleted (moved to MusicManager) |
| `Timer { id: musicAccentRetry }` | Deleted (moved to MusicManager) |
| `_accentRetryCount` | Deleted |
