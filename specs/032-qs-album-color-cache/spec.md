# Feature Specification: Quickshell Album Color Cache

**Feature Branch**: `032-qs-album-color-cache`
**Created**: 2026-03-15
**Status**: Draft
**Input**: User description: "quickshell: делать перерасчет цвета подсветки только если альбом поменялся, а в противном случае можно просто повторять тот цвет что был из кэша"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Skip redundant color extraction on same-album track change (Priority: P1)

When a user is listening to an album and the track advances to the next song on the same album, the panel highlight color should remain unchanged without triggering any color recalculation. The previously computed accent color is reused instantly.

**Why this priority**: This is the core optimization — most listening sessions involve consecutive tracks from the same album, making this the highest-frequency scenario. Eliminating redundant Canvas pixel sampling directly reduces CPU overhead and prevents visual flicker during track transitions.

**Independent Test**: Play an album with 3+ tracks. Advance tracks and observe that the accent color remains stable without any brief flash, reset, or delay between tracks.

**Acceptance Scenarios**:

1. **Given** a track is playing with accent color displayed, **When** the next track on the same album starts, **Then** the accent color remains identical without any recalculation or visual transition.
2. **Given** a track is playing, **When** the track metadata updates but the album name and cover art URL are unchanged, **Then** no color extraction is triggered.

---

### User Story 2 - Recalculate color when album actually changes (Priority: P1)

When the user switches to a track from a different album (different cover art), the system must extract a new accent color from the new album art.

**Why this priority**: Equal to P1 — correctness of recalculation is as important as avoiding redundant computation. Without this, the panel would show stale colors for new albums.

**Independent Test**: Play a track from Album A, then switch to a track from Album B with visually different cover art. The accent color should update to reflect Album B's artwork.

**Acceptance Scenarios**:

1. **Given** Album A is playing with its accent color, **When** user switches to a track from Album B (different cover art URL), **Then** a new accent color is extracted from Album B's cover art.
2. **Given** Album A is playing, **When** user switches to a track with the same album name but a different cover art URL, **Then** a new accent color is extracted.
3. **Given** Album A is playing, **When** user switches to a track with a different album name but identical cover art URL, **Then** the cached color for that URL is reused (no redundant extraction).

---

### User Story 3 - Shared cache between bar and side panel (Priority: P2)

Both the bar media module and the side panel music widget should share a single color cache so that a color extracted by one component is immediately available to the other without duplicate computation.

**Why this priority**: Currently both the bar and panel maintain independent caches, leading to duplicate extractions for the same cover art. Sharing eliminates this redundancy.

**Independent Test**: Open the side panel while music plays. The accent color should appear instantly on both bar and panel without two separate extraction cycles.

**Acceptance Scenarios**:

1. **Given** the bar extracts an accent color for Album A, **When** the side panel is opened, **Then** the panel uses the already-cached color without triggering its own extraction.
2. **Given** the panel extracted a color, **When** the bar needs to display the same album's accent, **Then** it reuses the cached value.

---

### Edge Cases

- What happens when cover art URL is empty or null (e.g., track with no embedded art)? The system should fall back to the theme default color without attempting extraction, same as current behavior.
- What happens when the same album name has different cover art across different music sources? The cache key should incorporate the cover art URL, so different artwork produces different colors.
- What happens when Quickshell restarts mid-playback? The color must be recomputed on first track display (no persistent disk cache required for this feature).
- What happens during rapid track skipping across multiple albums? The debounce mechanism (existing timer) should coalesce rapid changes, and only the final album's color should be extracted.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST compare the current cover art URL against the previously processed cover art URL before initiating color extraction.
- **FR-002**: The system MUST skip color extraction entirely when the cover art URL has not changed, reusing the last computed color.
- **FR-003**: The system MUST trigger a fresh color extraction when the cover art URL changes to a new value.
- **FR-004**: The system MUST maintain a single shared color cache accessible by both the bar media module and the side panel music widget.
- **FR-005**: The system MUST preserve existing fallback behavior (theme default color) when no cover art is available or extraction fails.
- **FR-006**: The system MUST preserve the existing debounce and retry mechanisms for color extraction timing.

### Key Entities

- **Album Identity**: The cover art URL that uniquely identifies an album's visual appearance. Used as the cache key to determine whether recalculation is needed.
- **Accent Color Cache**: A shared mapping from cover art URL to the extracted accent color. Accessible by all UI components. In-memory only (not persisted to disk).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When advancing tracks within the same album, zero color extraction operations are performed — the cached color is returned instantly.
- **SC-002**: When switching albums, a new color is extracted within the existing timing budget (debounce + retry cycle).
- **SC-003**: Both the bar and side panel display identical accent colors for the same album without performing independent extractions.
- **SC-004**: No visual flicker or color reset is observable during same-album track transitions.

## Assumptions

- Album identity can be reliably determined from the cover art URL. Two tracks with the same cover URL are considered the same album for color purposes.
- No persistent (disk-based) caching is needed — the in-memory cache is sufficient since color extraction is fast and only matters during active playback sessions.
- The existing color sampling algorithm and threshold configuration remain unchanged — this feature only optimizes *when* the sampler is invoked, not *how* it samples.
