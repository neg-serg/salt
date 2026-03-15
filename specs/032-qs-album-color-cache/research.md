# Research: Quickshell Album Color Cache

## R1: QML Canvas.drawImage from hidden Image element

**Decision**: Use a hidden `Image` (not `HiDpiImage`) at sampler resolution inside MusicManager, co-located with a `Canvas` that calls `drawImage()` on it.

**Rationale**: QML's `Canvas.drawImage()` accepts any `Item` with a visual representation. A small `Image` element at 48×48 px is lightweight and decoupled from the display-size Images in Media.qml/Music.qml. Using standard `Image` (not `HiDpiImage`) avoids unnecessary high-DPI overhead for a sampler that only needs pixel data.

**Alternatives considered**:
- *Keep Canvas in Media.qml, write results to MusicManager*: Creates coupling — Media.qml must be loaded/visible for accent to work. Side panel opened without bar visible would have no accent.
- *Use ImageProvider or C++ plugin*: Over-engineered for a 48×48 pixel sampling operation.
- *Use ShaderEffect for color extraction*: Would require custom GLSL, much more complex than JS pixel loop.

## R2: Cache eviction strategy

**Decision**: Simple JS object (`{}`) with no eviction. Cache grows unbounded within session.

**Rationale**: Each cache entry is one URL string key + one QML `color` value (~100 bytes). Even 1000 albums in a session = ~100 KB — negligible. Quickshell restarts clear the cache naturally.

**Alternatives considered**:
- *LRU cache with max size*: Unnecessary complexity for negligible memory savings.
- *Single-entry cache (only current)*: Would lose the benefit of instant restore when switching back to a previously played album.
- *Persistent disk cache*: Out of scope per spec; adds complexity (file I/O, invalidation) for minimal benefit.

## R3: Album identity — cover URL vs album name

**Decision**: Use `coverUrl` (MPRIS `trackArtUrl`) as the sole cache key and change-detection key.

**Rationale**: Cover URL is the most reliable identity for visual appearance. Two tracks with the same cover URL always produce the same accent color. Album name can have encoding variations and doesn't guarantee visual identity. The cover URL is already available as `MusicManager.coverUrl`.

**Alternatives considered**:
- *Album name + artist composite key*: Unreliable — same album can have different spellings; different albums can share artwork.
- *Hash of cover image data*: Too expensive — requires loading and hashing the full image just to check identity.
- *Combined URL + album name*: Redundant — if URL is the same, the image is the same.

## R4: Timing of URL comparison (skip-extraction gate)

**Decision**: Compare `coverUrl` against `_lastSampledUrl` in the `onCoverUrlChanged` handler, *before* starting the debounce timer.

**Rationale**: This is the earliest possible interception point. If the URL hasn't changed, no timer is started, no Canvas paint is requested, no Image load is triggered — truly zero work. The debounce timer itself costs nothing, but preventing it avoids the downstream Canvas paint cycle entirely.

**Alternatives considered**:
- *Compare inside Canvas.onPaint*: Too late — debounce timer already fired, Canvas context already created. Saves sampling cost but not timer/paint overhead.
- *Compare after Image.onStatusChanged*: Misses the case where URL changes to the same value without Image reload (e.g., metadata-only updates).
