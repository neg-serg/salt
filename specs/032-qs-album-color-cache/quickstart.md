# Quickstart: Quickshell Album Color Cache

## What this feature does

Optimizes album art accent color extraction in the Quickshell panel. Instead of recalculating the dominant color from album artwork on every track change, the system caches the result and only recalculates when the album actually changes (different cover art URL).

## Files to modify

1. **`dotfiles/dot_config/quickshell/Services/MusicManager.qml`** — Add accent color properties, hidden Image+Canvas sampler, cache logic, debounce/retry timers
2. **`dotfiles/dot_config/quickshell/Bar/Modules/Media.qml`** — Remove local Canvas/cache/timers, alias `MusicManager.accentColor`
3. **`dotfiles/dot_config/quickshell/Widgets/SidePanel/Music.qml`** — Remove local Canvas/cache/timers, alias `MusicManager.accentColor`

## Key file unchanged

- **`dotfiles/dot_config/quickshell/Helpers/AccentSampler.js`** — Pure algorithm, no changes needed

## How to verify

1. Start MPD with a playlist containing multiple albums
2. Play a track — observe accent color appears on bar and side panel
3. Skip to next track on **same album** — accent color should remain stable with no flicker
4. Switch to a track on a **different album** — accent color should update
5. Open side panel — should show same accent color as bar, instantly (no independent extraction)

## Implementation order

1. Add accent infrastructure to MusicManager (properties, Image, Canvas, timers)
2. Simplify Media.qml (remove sampling, bind to MusicManager)
3. Simplify Music.qml (remove sampling, bind to MusicManager)
4. Manual verification with MPD playback
