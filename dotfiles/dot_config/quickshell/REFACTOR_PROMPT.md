# Quickshell Codebase & UX Improvement — Autonomous Work Prompt

> **Usage:** Feed this entire file as a prompt to Claude Code in the `~/src/salt` working directory.
> It is a self-contained work plan with embedded context, grounded examples, and verification steps.

---

<system-context>
You are working on a Quickshell-based Wayland desktop shell (status bar + greeter/lock screen).
The codebase lives at `dotfiles/dot_config/quickshell/` inside a Salt+Chezmoi configuration repo.

Tech stack: QML 6 (Qt 6), JavaScript helpers, GLSL fragment shaders, Quickshell runtime (not standard Qt Quick).
Total: ~135 QML files, ~19 JS helpers, ~17,300 LOC across 6 modules + greeter.

IMPORTANT: Read `CLAUDE.md` at the repo root before making any changes — it defines commit style,
conventions, and platform constraints. Read `memory/quickshell.md` for architectural overview.
</system-context>

---

## GRACE Framework

<goal>
Improve the Quickshell codebase along two axes:

1. **Code quality** — reduce duplication, extract hardcoded values to theme tokens,
   enforce consistent patterns, improve error visibility.
2. **UX polish** — smoother transitions on theme changes, responsive layout robustness,
   animation standardization, graceful degradation when services are unavailable.

The work should be incremental and non-breaking: each change must leave the shell fully functional.
Do NOT restructure the module/directory layout — only refactor within existing boundaries.
</goal>

<requirements>
### R1: No Behavioral Regressions
Every visual element must render identically after refactoring, unless the change explicitly
improves UX (e.g., adding a color transition). Test by visual inspection after each file change.

### R2: Preserve Existing API Surface
Public properties and signals on Components/* and Services/* are consumed by other modules.
Renaming or removing them requires updating all call sites. Prefer additive changes.

### R3: Theme Token Discipline
All numeric constants controlling visual appearance (colors, opacities, spacing multipliers,
animation durations, feather distances) must live in `Settings/Theme.qml` as named properties.
QML files should reference `Theme.xxx`, never inline magic numbers.

### R4: Incremental Commits
Each logical unit of work should be a separate commit following `[quickshell] description` style.
Do not batch unrelated changes into one commit.
</requirements>

---

## Action Groups

Each action group is independent and can be executed in any order.
Within a group, steps are sequential. After each group, run the verification checklist.

---

### AG1: Extract Panel Duplication in Bar.qml

<problem>
`Bar/Bar.qml` (1,427 LOC) contains two nearly identical panel definitions:
- **leftPanel** (lines ~400–700): WlrLayershell window anchored left
- **rightPanel** (lines ~750–1050): WlrLayershell window anchored right

These share ~30 identical property declarations:
```qml
// Duplicated verbatim in both panels (Bar.qml:414-449 and Bar.qml:764-815):
property real s: Theme.scale(xxxPanel.screen)
property int barHeightPx: Math.round(Theme.panelHeight * s)
property int sideMargin: Math.round(_sideMarginBase * s)
property int widgetSpacing: Math.round(Theme.panelWidgetSpacing * s)
property int interWidgetSpacing: Math.max(widgetSpacing, Math.round(widgetSpacing * 1.35))
property int seamWidth: Math.max(8, Math.round(widgetSpacing * 0.85))
property real seamTaperTop: 0.25
property real seamTaperBottom: 0.9
property real seamOpacity: 0.55
property color seamFillColor: Color.withAlpha(Color.mix(Theme.surfaceVariant, Theme.background, 0.45), seamOpacity)
property bool panelTintEnabled: true
property color panelTintColor: Color.withAlpha("#ff2a36", 0.75)   // ← hardcoded red!
property real panelTintStrength: 1.0
property real panelTintFeatherTop: 0.08
property real panelTintFeatherBottom: 0.35
```
</problem>

<actions>
1. **Read** `Bar/Bar.qml` fully. Identify every property that appears in both leftPanel and rightPanel
   with identical definitions (same formula, same constants).

2. **Create** `Bar/PanelMetrics.js` — a pure JS helper that computes derived panel metrics from
   Theme tokens and a scale factor:
   ```js
   // Bar/PanelMetrics.js
   function compute(Theme, scale) {
       return {
           barHeightPx: Math.round(Theme.panelHeight * scale),
           widgetSpacing: Math.round(Theme.panelWidgetSpacing * scale),
           interWidgetSpacing: Math.max(
               Math.round(Theme.panelWidgetSpacing * scale),
               Math.round(Theme.panelWidgetSpacing * scale * Theme.panelInterWidgetRatio)
           ),
           seamWidth: Math.max(
               Theme.panelSeamMinPx,
               Math.round(Theme.panelWidgetSpacing * scale * Theme.panelSeamWidthRatio)
           ),
           // ... all shared computed values
       };
   }
   ```

3. **Add Theme tokens** for the magic numbers currently inline in both panels:
   ```
   panelInterWidgetRatio: 1.35     (was: hardcoded 1.35)
   panelSeamWidthRatio: 0.85       (was: hardcoded 0.85)
   panelSeamMinPx: 8               (was: hardcoded 8)
   panelSeamTaperTop: 0.25         (was: hardcoded 0.25)
   panelSeamTaperBottom: 0.9       (was: hardcoded 0.9)
   panelSeamOpacity: 0.55          (was: hardcoded 0.55)
   panelSeamColorMixRatio: 0.45    (was: hardcoded 0.45)
   panelTintColor: "#ff2a36"       (was: hardcoded in Bar.qml)
   panelTintAlpha: 0.75            (was: hardcoded 0.75)
   panelTintStrength: 1.0          (was: hardcoded 1.0)
   panelTintFeatherTop: 0.08       (was: hardcoded 0.08)
   panelTintFeatherBottom: 0.35    (was: hardcoded 0.35)
   ```

4. **Replace** the duplicated property blocks in both panels with:
   ```qml
   readonly property var pm: PanelMetrics.compute(Theme, s)
   property int barHeightPx: pm.barHeightPx
   property int widgetSpacing: pm.widgetSpacing
   // ... etc
   ```

5. **Remove** the `mixColor()`, `grayOf()`, `desaturateColor()` functions from Bar.qml root scope
   (lines 21–34). These duplicate `Helpers/Color.js` — use `Color.mix()` and `Color.towardsBlack()`
   instead. Update `vpnAccentColor()` to use the imported helpers.
</actions>

<constraints>
- leftPanel and rightPanel DIFFER in: `anchors` direction, `seamTiltSign` (1.0 vs -1.0),
  `WlrLayershell.namespace`, and the child widget rows. Do NOT try to merge them into one component —
  only extract the shared *computed metrics*.
- The `seamPanel` (lines 1240–1427) has its own set of seam parameters that are intentionally
  different from the side panels. Do not merge those.
</constraints>

<verification>
- [ ] `grep -n 'ff2a36' Bar/Bar.qml` returns 0 matches (color moved to Theme)
- [ ] `grep -n '0\.85\|1\.35' Bar/Bar.qml` returns 0 matches for panel metric contexts
- [ ] `grep -c 'mixColor\|grayOf\|desaturateColor' Bar/Bar.qml` returns 0 (use Color.js)
- [ ] Bar renders identically on both halves of the screen
- [ ] VPN accent tint still works (test: `QS_WEDGE_DEBUG=1`)
</verification>

---

### AG2: Eliminate Hardcoded Colors

<problem>
15+ hardcoded color literals scattered across the codebase:

| File | Line(s) | Value | Purpose |
|------|---------|-------|---------|
| `Bar/Bar.qml` | 446, 812 | `#ff2a36` | Panel tint accent (red) |
| `Bar/Bar.qml` | 463, 830 | `#000000` | Bar backdrop |
| `Bar/Bar.qml` | canvas fills | `#ffffffff`, `#000000ff` | Triangle overlay |
| `Components/WidgetCapsule.qml` | 12 | `#000000` | Fallback color |
| `greeter/ShellGlobals.qml` | 12-18 | 7 RGBA values | Greeter palette |
</problem>

<actions>
1. **For Bar.qml colors**: handled by AG1 (panelTintColor token). Additionally:
   - Replace `color: "#000000"` backdrop (lines 463, 830) with `Theme.panelBackdropColor`
   - Replace Canvas fill styles with `Theme.background.toString()` / `Theme.panelOverlayColor`

2. **For WidgetCapsule.qml**: replace `property color fallbackColor: "#000000"` with
   `property color fallbackColor: Theme.surface` — this is semantically correct since the
   fallback should match the surface, not be an arbitrary black.

3. **For greeter/ShellGlobals.qml**: the greeter has its own independent theme system.
   Create `greeter/GreeterTheme.qml` singleton that reads from a `.jsonc` file
   (matching the pattern in `Settings/Theme.qml`), or at minimum extract the colors to
   named properties with semantic names:
   ```qml
   // Current (lines 12-18):
   readonly property color bar: "#30c0ffff"
   readonly property color barOutline: "#50ffffff"

   // Improved — at least make them configurable via env or file:
   readonly property color bar: _fromEnv("QS_GREETER_BAR_COLOR", "#30c0ffff")
   ```

4. **Search for any remaining hex literals**:
   ```bash
   rg '#[0-9a-fA-F]{6,8}' --glob '*.qml' dotfiles/dot_config/quickshell/
   ```
   Each hit should either reference a Theme token or have a comment explaining why it's inline.
</actions>

<verification>
- [ ] `rg '#[0-9a-fA-F]{6}' --glob '*.qml' dotfiles/dot_config/quickshell/ | grep -v Theme | grep -v greeter | grep -v '\/\/'` returns only justified cases
- [ ] WidgetCapsule renders with correct fallback on missing backgroundKey
</verification>

---

### AG3: Standardize Error Handling

<problem>
193+ try-catch blocks across the codebase. Most have empty catch bodies or silently swallow errors:

```js
// Helpers/Color.js:35
} catch(e) {}
return null;

// Services/MusicMeta.qml — 58 try-catch blocks, none log

// Services/Connectivity.qml:71
} catch (e) { /* ignore */ }
```

This makes debugging extremely difficult — failures in color parsing, metadata extraction,
or network probing are invisible.
</problem>

<actions>
1. **Helpers/*.js files**: Add `console.warn` to every catch block with the function name:
   ```js
   // Before:
   } catch(e) {}

   // After:
   } catch(e) { console.warn("[Color._toRgb]", e) }
   ```

   Apply to all functions in: `Color.js`, `Utils.js`, `Format.js`, `RichText.js`, `Time.js`,
   `AccentSampler.js`, `CapsuleMetrics.js`, `WidgetBg.js`.

   **Exception**: Keep silent catches in performance-hot paths that run every frame
   (e.g., `CapsuleMetrics.metrics()` if called on every layout pass). Add a comment explaining why.

2. **Services/*.qml**: Add `console.warn` to catch blocks in:
   - `Connectivity.qml` (lines 60-72, 91, 101-106)
   - `MusicMeta.qml` (all 58 blocks — use a batch find-replace)
   - `MusicPlayers.qml` (cover URL resolution)
   - `Weather.qml` (JSON parsing)

3. **Theme.qml**: The `scale()` function (line 27) has an empty catch. Log it:
   ```qml
   } catch (e) { console.warn("[Theme.scale]", e) }
   ```
</actions>

<constraints>
- Do NOT change the return values or control flow — only add logging to existing catch blocks.
- Use `console.warn`, not `console.error` (Quickshell surfaces errors more aggressively).
- Keep one-liner format for simple catches: `} catch(e) { console.warn("[X]", e) }`
</constraints>

<verification>
- [ ] `rg 'catch\s*\(e\)\s*\{\s*\}' --glob '*.js' --glob '*.qml' dotfiles/dot_config/quickshell/` returns 0 matches
- [ ] `rg 'catch.*ignore' --glob '*.qml' dotfiles/dot_config/quickshell/` returns 0 matches
- [ ] Shell starts without console spam under normal operation
</verification>

---

### AG4: Centralize Animation Tokens

<problem>
Animation durations and easing curves are scattered across components with no shared vocabulary:

- `Components/NumberFadeBehavior.qml` — defines its own duration
- `Components/ColorFastInOutBehavior.qml` — independent duration
- `Bar/Modules/Media.qml:92` — `Timer { interval: 60 }` (accent debounce)
- `Bar/Modules/Media.qml:122` — `Timer { interval: Theme.mediaAccentRetryMs }` (some use Theme, some don't)
- `Services/Connectivity.qml:26-27` — `fastIntervalMs: 500`, `fastDurationMs: 10000` (inline)
- Various `Behavior on` blocks with ad-hoc durations

No color transition when theme changes — colors snap instantly.
</problem>

<actions>
1. **Add to Theme.qml** a block of animation tokens:
   ```qml
   // Animation timing
   readonly property int animFastMs: 100
   readonly property int animNormalMs: 200
   readonly property int animSlowMs: 400
   readonly property int animDebounceMs: 60
   readonly property string animEasing: "InOutQuad"
   ```

2. **Update Behavior components** to reference these tokens:
   - `NumberFadeBehavior.qml`: use `Theme.animNormalMs` as default duration
   - `ColorFastInOutBehavior.qml`: use `Theme.animFastMs`
   - `ColorRippleBehavior.qml`: use `Theme.animSlowMs`

   Each component should still accept a `duration` property override — the Theme value
   is just the default.

3. **Add Behavior on color** to WidgetCapsule.qml for smooth theme transitions:
   ```qml
   Behavior on color {
       ColorAnimation { duration: Theme.animNormalMs; easing.type: Easing.InOutQuad }
   }
   ```
   This will make all capsule-based widgets smoothly transition colors when the theme changes.

4. **Replace inline Timer intervals** that are purely cosmetic debounces:
   - `Media.qml:92` `interval: 60` → `interval: Theme.animDebounceMs`
   - Keep functional timers (polling intervals, retry timers) as-is — those are not animations.
</actions>

<constraints>
- Functional timers (network polling, health checks, retry) are NOT animation tokens.
  Only visual/cosmetic timing should use `Theme.animXxxMs`.
- Connectivity's `fastIntervalMs`/`fastDurationMs` are functional — leave them.
- Color animations on frequently-changing properties (e.g., audio level bars) may cause
  visual lag — test and disable if needed.
</constraints>

<verification>
- [ ] Theme change (edit `.theme.json`) shows smooth color transitions on capsules
- [ ] No visible lag on audio level indicators or clock updates
- [ ] `rg 'interval:\s*\d+' Bar/Modules/Media.qml` shows no bare numeric intervals for debounces
</verification>

---

### AG5: Clean Up Color.js Duplication in Bar.qml

<problem>
Bar.qml (lines 21-34) redefines three functions that already exist in `Helpers/Color.js`:

```qml
// Bar.qml:21-34 (DUPLICATE)
function mixColor(a, b, t) { ... }      // = Color.mix()
function grayOf(c) { ... }              // = Color.toHsl() + desaturate
function desaturateColor(c, amount) { ... } // = custom, but composable from Color.js
```

Bar.qml already imports `Color.js` on line 13: `import "../Helpers/Color.js" as Color`
</problem>

<actions>
1. **Add** a `desaturate(color, amount)` function to `Helpers/Color.js` that replicates
   the `desaturateColor` logic using existing `_toRgb` and `mix`:
   ```js
   function desaturate(c, amount) {
       try {
           var rgb = _toRgb(c);
           if (!rgb) return c;
           var clamped = Math.min(1, Math.max(0, Number(amount) || 0));
           var y = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
           var gray = Qt.rgba(y, y, y, rgb.a);
           return mix(c, gray, clamped);
       } catch(e) { console.warn("[Color.desaturate]", e); return c }
   }
   ```

2. **Remove** lines 21-34 from Bar.qml.

3. **Update** `vpnAccentColor()` (Bar.qml:35-40):
   ```qml
   // Before:
   function vpnAccentColor() {
       const boost = Theme.vpnAccentSaturateBoost || 0;
       const desat = Theme.vpnDesaturateAmount || 0;
       const base = Color.saturate(Theme.accentPrimary, boost);
       return desaturateColor(base, desat);  // ← uses local function
   }

   // After:
   function vpnAccentColor() {
       const boost = Theme.vpnAccentSaturateBoost || 0;
       const desat = Theme.vpnDesaturateAmount || 0;
       const base = Color.saturate(Theme.accentPrimary, boost);
       return Color.desaturate(base, desat);  // ← uses Color.js
   }
   ```

4. **Search for other `mixColor` / `grayOf` call sites** in Bar.qml and replace with
   `Color.mix()` / inline luminance calculation.
</actions>

<verification>
- [ ] `grep -n 'function mixColor\|function grayOf\|function desaturateColor' Bar/Bar.qml` returns 0
- [ ] VPN accent color renders the same (compare before/after screenshot)
</verification>

---

### AG6: Tokenize Media.qml Magic Numbers

<problem>
`Bar/Modules/Media.qml` contains 20+ inline magic numbers for layout calculations:

```qml
// Line 18: albumActionIconScale: 0.6
// Line 40: panelOverlayContentPadding: Math.max(2, Math.round(... * 0.4))
// Line 47: panelOverlayWidthShare fallback: 0.45
// Line 54: panelOverlayBgOpacity fallback: 0.6
// Line 57: mediaRowSpacing: Math.max(4, Math.round(... * 0.6))
// Line 58: stretchTrackHeightHint: ... * 1.6 ...
```

These are unreachable by theme customization and undocumented.
</problem>

<actions>
1. **Add to Theme.qml**:
   ```qml
   // Media widget layout
   readonly property real mediaAlbumActionIconScale: 0.6
   readonly property real mediaPanelOverlayContentPaddingRatio: 0.4
   readonly property int mediaPanelOverlayContentPaddingMin: 2
   readonly property real mediaPanelOverlayWidthShare: 0.45
   readonly property real mediaPanelOverlayBgOpacity: 0.6
   readonly property real mediaRowSpacingRatio: 0.6
   readonly property int mediaRowSpacingMin: 4
   readonly property real mediaStretchTrackHeightRatio: 1.6
   ```

2. **Update Media.qml** to reference these tokens. The Settings.settings override chain
   (`Settings > Theme > fallback`) should use the Theme token as the new fallback:
   ```qml
   // Before (line 47):
   return 0.45;

   // After:
   return Theme.mediaPanelOverlayWidthShare;
   ```

3. **Document** each token with a one-line comment in Theme.qml explaining what it controls.
</actions>

<verification>
- [ ] `rg '0\.45|0\.6[^0-9]' Bar/Modules/Media.qml` — only references to Theme tokens remain
- [ ] Media widget renders identically in compact, stretch, and panel modes
</verification>

---

### AG7: Improve Service Resilience

<problem>
Services assume their backing processes are available and don't handle unavailability:

1. **Connectivity.qml**: `rsmetrx` stream (line 96-107) — if `rsmetrx` binary is missing,
   ProcessRunner silently fails. No indication to the user.

2. **MusicMeta.qml**: introspection chain (`ffprobe` → `mediainfo` → `sox`) — if none are
   installed, metadata is silently empty.

3. **Weather.qml**: if the weather service URL is unreachable, no fallback or retry with backoff.

4. **Audio.qml**: PwObjectTracker dependency — no handling if PipeWire is unavailable.
</problem>

<actions>
1. **Add a `serviceReady` pattern**: For each service that depends on an external process,
   add a `readonly property bool available: <check>` that downstream consumers can bind to.

   Example for Connectivity:
   ```qml
   // After rsStream ProcessRunner:
   readonly property bool trafficAvailable: rsStream.running || rsStream.exitCode === 0
   ```

2. **MusicMeta.qml**: Add a `property string introspectionTool: ""` that records which tool
   succeeded. This allows the UI to show a subtle indicator (or tooltip) about metadata quality.

3. **For missing binaries**: Add `onError` or `onExitCode` handlers to ProcessRunner instances
   that log a one-time warning:
   ```qml
   property bool _rsmetrxWarned: false
   ProcessRunner {
       id: rsStream
       cmd: ["rsmetrx"]
       onExitCode: (code) => {
           if (code === 127 && !root._rsmetrxWarned) {
               console.warn("[Connectivity] rsmetrx not found — traffic monitoring disabled")
               root._rsmetrxWarned = true
           }
       }
   }
   ```
</actions>

<constraints>
- Do NOT add retry loops for missing binaries — that would waste resources.
- The `available` property is purely informational for UI binding. Do not block service init.
- Keep the ProcessRunner API unchanged — add new signals/properties only if needed.
</constraints>

<verification>
- [ ] Remove `rsmetrx` from PATH temporarily → console shows one warning, no spam
- [ ] `MusicMeta.introspectionTool` populates correctly when playing a track
- [ ] Services that depend on missing tools degrade gracefully (show default/empty state)
</verification>

---

### AG8: Enforce Consistent Property Naming

<problem>
Inconsistent patterns across the codebase:

| Pattern | Examples | Files |
|---------|----------|-------|
| `_private` (single underscore) | `_naturalWidth`, `_contentWidth` | Media.qml, CenteredCapsuleRow |
| `__private` (double underscore) | `_themePartCache` | Theme.qml |
| No prefix for private | `panelHovering`, `fastMode` | Bar.qml, Connectivity.qml |
| `xxxMode` for enum-like | `iconLayoutMode`, `stretchMode` | Media.qml |
| `xxxMode` for boolean | `fastMode` | Connectivity.qml |
| `isXxx` for boolean | `isStopped` | MusicManager.qml |
| No prefix for boolean | `hasLink`, `accentReady` | Connectivity, Media |
</problem>

<actions>
This is a convention-setting action — document the rules, then apply incrementally.

1. **Document** in a new section of `Docs/CodingConventions.md`:
   ```
   ## Property Naming

   - Private (internal to component): `_singleUnderscore` prefix
   - Public (part of component API): no prefix
   - Boolean state: `isXxx` or `hasXxx` (e.g., `isPlaying`, `hasLink`)
   - Boolean feature flag: `xxxEnabled` (e.g., `panelTintEnabled`)
   - Enum-like string: `xxxMode` (e.g., `iconLayoutMode`)
   - Computed readonly: `readonly property` (always)
   ```

2. **Apply to new code only** — do NOT mass-rename existing properties (breaks external consumers).
   Only rename properties that are clearly private (prefixed with `_` or `__`) to use single `_`.

3. **Specific renames** (safe because double-underscore implies internal):
   - `Theme.qml`: `__` → `_` for `_themePartCache`, `_themePartLoaded` (already single `_`)
   - Verify no double-underscore properties exist: `rg '__[a-z]' --glob '*.qml'`
</actions>

<verification>
- [ ] `Docs/CodingConventions.md` exists with property naming section
- [ ] `rg '__[a-z]' --glob '*.qml' dotfiles/dot_config/quickshell/` returns 0 matches
</verification>

---

### AG9: Add Color Transition on Theme Change

<problem>
When the user edits `.theme.json` (or the theme auto-reloads from wallust), all colors snap
instantly. This is jarring — a 200ms cross-fade would feel significantly more polished.

The Theme.qml singleton already has a `_themeLoaded` flag and a `themeMergeTimer` (80ms debounce).
The infrastructure for detecting theme changes exists.
</problem>

<actions>
1. **Add to Theme.qml** a transition signal:
   ```qml
   signal themeTransitionStarted()
   signal themeTransitionFinished()
   ```

2. **In `_performThemeMerge()`** (called by `themeMergeTimer`), emit `themeTransitionStarted()`
   before applying new values and set a timer to emit `themeTransitionFinished()` after
   `animNormalMs` milliseconds.

3. **In WidgetCapsule.qml**, add:
   ```qml
   Behavior on _baseColor {
       enabled: Theme._themeLoaded  // Don't animate initial load
       ColorAnimation { duration: Theme.animNormalMs }
   }
   ```

4. **In Bar.qml**, add Behavior on `barBgColor` and `seamFillColor` for both panels.

5. **Test edge cases**:
   - Rapid theme changes (wallust cycling) — should not queue up, latest wins
   - Initial load — should NOT animate (would flash from default to theme)
   - Components created after theme load — should get final color immediately
</actions>

<constraints>
- Only animate color properties. Do NOT animate size/position (would cause layout thrashing).
- The `enabled: Theme._themeLoaded` guard is critical — without it, the shell startup
  would show a slow fade from black/default to the actual theme.
- Test with `QS_WEDGE_DEBUG=1` to verify seam colors also transition.
</constraints>

<verification>
- [ ] Edit `~/.config/quickshell/Theme/.theme.json`, change `accentPrimary` → colors fade smoothly
- [ ] Kill and restart quickshell → no fade on startup, colors appear immediately
- [ ] Rapid edits to theme file → no animation stacking or visual glitches
</verification>

---

### AG10: Improve Clamp Pattern Consistency

<problem>
`Math.max(0, Math.min(1, x))` appears ~50 times across the codebase. This is the standard
clamp-to-[0,1] pattern, but it's verbose and easy to get wrong (swapping min/max).

`Helpers/Utils.js` already has a `clamp` function, but it's not used consistently.
`Bar.qml:1283` even defines a local `seamClamp01()` function.
</problem>

<actions>
1. **Verify** `Utils.js` has a `clamp(val, min, max)` function. If not, add one:
   ```js
   function clamp(val, lo, hi) {
       var v = Number(val);
       return v < lo ? lo : (v > hi ? hi : v);
   }
   function clamp01(val) { return clamp(val, 0, 1); }
   ```

2. **In files that already import Utils.js**, replace `Math.max(0, Math.min(1, x))` with
   `Utils.clamp01(x)`. Priority files:
   - `Bar/Bar.qml` (import exists, ~15 clamp patterns + local `seamClamp01`)
   - `Bar/Modules/Media.qml` (import via `../../Helpers/Utils.js`)
   - `Helpers/Color.js` (has its own `_clamp01` — keep it internal, but ensure consistency)

3. **Remove** `seamClamp01()` from Bar.qml:1283 — replace call sites with `Utils.clamp01()`.

4. **Do NOT change** `Color.js`'s internal `_clamp01` — it's a private helper in a hot path
   and avoiding the cross-module call is intentional.
</actions>

<verification>
- [ ] `grep -c 'Math.max(0.*Math.min(1\|Math.min(1.*Math.max(0' Bar/Bar.qml` returns 0
- [ ] `grep 'seamClamp01' Bar/Bar.qml` returns 0
- [ ] All seam taper/feather computations produce identical results
</verification>

---

## Evaluation Criteria

After completing all action groups, verify the overall result:

<evaluation>
### Code Metrics (measure with `rg` and `wc`)
- [ ] Bar.qml LOC reduced by ≥15% (target: <1,200 from 1,427)
- [ ] Zero hardcoded hex colors outside Theme.qml and greeter/ShellGlobals.qml
- [ ] Zero empty catch blocks (`catch(e) {}` or `catch (e) { /* ignore */ }`)
- [ ] All animation durations reference Theme tokens (except functional timers)

### UX Verification (visual inspection)
- [ ] Theme color change triggers smooth 200ms transition on all capsule widgets
- [ ] No visible difference in bar layout, seam geometry, or widget spacing
- [ ] VPN accent tint renders correctly
- [ ] Media widget works in all 3 modes (compact/stretch/panel)
- [ ] Missing `rsmetrx` produces one warning, not continuous errors

### Architecture
- [ ] No new files created except: `Bar/PanelMetrics.js`, `Docs/CodingConventions.md`
- [ ] All changes follow `[quickshell] description` commit style
- [ ] No public property renames (API stability)
</evaluation>

---

## File Reference Map

<file-map>
These are the primary files touched by this refactoring work:

### Modified
- `Bar/Bar.qml` — AG1, AG2, AG4, AG5, AG10 (panel extraction, colors, animations, clamp)
- `Bar/Modules/Media.qml` — AG4, AG6, AG10 (tokens, animations, clamp)
- `Settings/Theme.qml` — AG1, AG2, AG4, AG6, AG9 (new tokens, animation props, transition)
- `Helpers/Color.js` — AG3, AG5 (error logging, desaturate function)
- `Helpers/Utils.js` — AG10 (clamp01 addition)
- `Components/WidgetCapsule.qml` — AG2, AG4, AG9 (fallback color, animation, transition)
- `Services/Connectivity.qml` — AG3, AG7 (error logging, resilience)
- `Services/MusicMeta.qml` — AG3, AG7 (error logging, introspection tool tracking)
- `Services/Weather.qml` — AG3 (error logging)
- `greeter/ShellGlobals.qml` — AG2 (color documentation/extraction)

### Created
- `Bar/PanelMetrics.js` — AG1 (shared panel computation)
- `Docs/CodingConventions.md` — AG8 (naming rules)

### Read-Only (context, do not modify)
- `memory/quickshell.md` — architectural overview
- `memory/generated/qml-components.md` — component API index
- `CLAUDE.md` — project conventions
</file-map>

---

## Execution Order Recommendation

```
AG3 (error handling)     — low risk, high debug value, no deps
AG5 (Color.js cleanup)   — small scope, prepares for AG1
AG10 (clamp patterns)    — small scope, prepares for AG1
AG1 (panel extraction)   — largest change, depends on AG5
AG2 (hardcoded colors)   — depends on AG1 for panel tint tokens
AG6 (Media tokens)       — independent
AG4 (animation tokens)   — independent
AG9 (theme transitions)  — depends on AG4
AG7 (service resilience) — independent
AG8 (naming conventions) — documentation, do last
```
