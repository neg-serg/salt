# Quickshell Comprehensive Improvement — Autonomous Work Prompt

> **Usage:** Feed this entire file as a prompt to Claude Code in the `~/src/salt` working directory.
> Self-contained work plan: embedded context, knowledge base pointers, grounded examples, verification.
> Designed to work from scratch — no prior conversation context required.

---

<system-context>
You are working on a Quickshell-based Wayland desktop shell (status bar + greeter/lock screen).
Codebase lives at `dotfiles/dot_config/quickshell/` inside a Salt+Chezmoi configuration repo.

Tech stack: QML 6 (Qt 6), JavaScript helpers, GLSL fragment shaders, Quickshell runtime.
Scale: ~135 QML files, ~19 JS helpers, ~17,300 LOC across 6 modules + greeter.

**Before any work:**
1. Read `CLAUDE.md` at the repo root — defines commit style, conventions, platform constraints.
2. Read the knowledge base router at `memory/MEMORY.md` — it links to:
   - `memory/quickshell.md` — architecture, component hierarchy (Capsule Tower), singletons, data flow
   - `memory/generated/qml-components.md` — full component API index (properties, signals, functions)
   - `memory/generated/qml-helpers.md` — all JS helper function signatures
3. Read `Docs/CodingConventions.md` — naming patterns, error handling rules, Theme token conventions.
4. Read `Docs/Config.md` — all Settings.json and Theme/.theme.json options.
5. Read `AGENTS.md` — commit style for this config, shader build rules.

**Commit style:** `[quickshell] description` (imperative mood, no trailing period).
Each Action Group = one atomic commit. Verify after each before proceeding.
</system-context>

---

## GRACE Framework

<goal>
Improve the Quickshell codebase along three axes:

1. **Code quality** — fix schema gaps, remove hardcoded paths, add missing error handling,
   improve service resilience, complete documentation coverage.
2. **UX polish** — greeter theming, accessibility toggles, graceful degradation feedback,
   keyboard navigation improvements, notification enhancements.
3. **New capabilities** — system monitoring widgets, quick-settings panel, enhanced
   calendar integration, configurable API endpoints, diagnostic overlay.
</goal>

<requirements>
- Every change must be backward-compatible: existing Settings.json and .theme.json files
  must continue working without modification.
- New Theme tokens must have sensible defaults matching current hardcoded behavior.
- New Settings properties must have defaults that preserve current UX.
- No new npm/pip/cargo dependencies — only system tools already likely installed.
- ProcessRunner commands must degrade gracefully when tools are missing.
- All code comments in English. Follow existing naming conventions.
- Each Action Group is independently testable and committable.
</requirements>

---

## Knowledge Base Quick-Reference

<knowledge-base>
These files contain the full codebase index. Read them to resolve questions about
component APIs, available Theme tokens, helper function signatures, and service interfaces.

| File | Content | When to read |
|------|---------|-------------|
| `memory/quickshell.md` | Architecture, modules, Capsule Tower hierarchy, data flow | Before any structural change |
| `memory/generated/qml-components.md` | Every QML component: properties, signals, functions (~2700 lines) | When modifying or extending components |
| `memory/generated/qml-helpers.md` | All 19 JS helper files with function signatures (~136 lines) | When adding/using helper functions |
| `Docs/CodingConventions.md` | Naming, error handling, Theme tokens, animation patterns | Before writing any code |
| `Docs/Config.md` | All Settings.json + Theme options with types and defaults | When adding new settings |
| `Docs/SettingsSchema.json` | Formal JSON schema for Settings.json (42 properties documented) | When adding settings |
| `Docs/ThemeTokens.md` | Theme token system, color conventions, deprecated tokens | When adding Theme tokens |
| `Settings/Theme.qml` | 243 token properties across 17 groups | When checking if a token exists |
</knowledge-base>

---

## Codebase Audit Findings (pre-verified)

<audit>
These findings were verified by automated exploration. Line numbers may shift slightly
if prior Action Groups modify the same files.

### Schema & Documentation Gaps
- **20 Settings used in code but missing from SettingsSchema.json**: `enableWedgeClipShader`,
  `hideSystemTrayCapsule`, `mediaIcon*` (12 variants), `mediaPanelButton*` (3),
  `mediaTitleSeparator`, `panelBgAlphaScale`, `panelSideMarginPx`, `systemTrayTightSpacing`
- **SettingsSchema.json** has 42 properties; code uses 62+

### Hardcoded Paths (portability issues)
- `greeter/BackgroundImage.qml`: `/home/<user>/.cache/greeter-wallpaper` — should use XDG_CACHE_HOME
- `Helpers/WorkspaceIcons.js` manifest: `/home/<user>/.local/share/fonts/` — should use XDG_DATA_HOME

### Missing Error Handling on ProcessRunner Instances
- `Bar/Modules/KeyboardLayoutHypr.qml` line ~166: `hyprctl switchxkblayout` — no onExited handler
- `Components/Cava.qml`: Cava process failure not logged, silent restart
- `Helpers/IdleInhibitor.qml`: systemd-inhibit failure not logged

### Hardcoded Timing Values Not in Theme
- `Services/Timers.qml` line 51: `2000ms` generic tick — should be `Theme.timerTick2sMs`
- `Bar/Modules/Media.qml` line 92: `60ms` color sampler debounce — should be Theme token
- `greeter/lock/Controller.qml` line 48: `500ms` lock animation — should be Theme token

### Service Resilience Weaknesses
- **HyprlandWatcher**: no validation that Hyprland is actually running; socat not checked
- **Connectivity**: ping target hardcoded to `8.8.8.8`; no DNS-based fallback; no `ip`/`dash` existence check
- **Weather.js**: API URLs hardcoded to open-meteo.com; no provider configurability

### Missing Capabilities (compared to typical Wayland bars)
- No system resource monitoring (CPU, RAM, disk, GPU)
- No battery/power widget
- No brightness control
- No Bluetooth status
- No notification center (only transient toasts via MusicPopup)
- No quick-settings panel (toggle WiFi, BT, DND, etc.)
- Greeter has no Theme integration (hardcoded cyan/white palette)
- No global reduced-motion preference (only env var QS_DISABLE_ANIMATIONS)
- Calendar shows holidays but no personal calendar integration

### Environment Variable Toggles (11 QS_* vars, all well-implemented)
QS_DISABLE_BAR, QS_MINIMAL_UI, QS_DISABLE_ANIMATIONS, QS_DISABLE_VISUALIZER,
QS_WEDGE_WIDTH_PCT, QS_DISABLE_WEDGE, QS_DISABLE_TRIANGLES, QS_WEDGE_DEBUG,
QS_WEDGE_SHADER_TEST, QS_ENABLE_WEDGE_CLIP
</audit>

---

## Action Groups

Each AG is an atomic unit of work. Execute sequentially; commit after each.
Priority order: correctness fixes → documentation → UX → new features.

---

### AG1 — Complete Settings Schema Documentation

<problem>
20 settings are used in QML/JS code but missing from `Docs/SettingsSchema.json`.
The schema is the contract for what Settings.json accepts. Missing entries mean
users have no way to discover these options without reading source code.
</problem>

<actions>
1. **Grep for all `Settings.settings.XXX` access patterns** across `*.qml` and `*.js`:
   ```bash
   rg 'Settings\.settings\.\w+' dotfiles/dot_config/quickshell/ --only-matching | sort -u
   ```
2. **Cross-reference against SettingsSchema.json** — identify every property used in code but
   not in the schema.
3. **For each missing property**, determine: type, default value, description, valid range.
   Find the default by reading the code that accesses it (typically a ternary or `|| default`).
4. **Add each property to SettingsSchema.json** in the appropriate section, following the existing
   format (JSON Schema style with `type`, `default`, `description`).
5. **Update `Docs/Config.md`** with the new settings in the appropriate sections.

**Grounded example — `panelBgAlphaScale`:**
Used in `Bar/Bar.qml` ~line 30: `Settings.settings.panelBgAlphaScale`.
Default: `0.2` (from `_defaultPanelAlphaScale`). Type: number 0..1.
Add to schema: `"panelBgAlphaScale": { "type": "number", "default": 0.2, "description": "..." }`
</actions>

<verification>
- `rg 'Settings\.settings\.\w+' ... --only-matching | sort -u | wc -l` ≥ schema property count
- `node -e "JSON.parse(require('fs').readFileSync('Docs/SettingsSchema.json'))"` — valid JSON
- Every setting in schema has a matching code access pattern
</verification>

---

### AG2 — Fix Hardcoded User Paths

<problem>
Two locations use `/home/<user>/` hardcoded paths, breaking portability if the username
or XDG directories differ. Quickshell provides `Quickshell.env()` for env var access.
</problem>

<actions>
1. **`greeter/BackgroundImage.qml`** — find the hardcoded wallpaper cache path.
   Replace with: `Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")`
   followed by `+ "/greeter-wallpaper"`.

2. **`Helpers/WorkspaceIcons.js`** — find hardcoded font paths in manifest loading.
   Replace `/home/<user>/.local/share/fonts/` with runtime XDG resolution.
   Note: The manifest.json file itself may contain hardcoded paths — check if it's
   loaded dynamically or statically. If static, add a comment documenting the dependency.

3. **Search for any remaining `/home/<user>/` references**:
   ```bash
   rg '/home/[^/]+' dotfiles/dot_config/quickshell/ --glob '*.qml' --glob '*.js'
   ```
   Exclude manifest.json (data file) and documentation files from the fix scope.
</actions>

<verification>
- `rg '/home/[^/]+' dotfiles/dot_config/quickshell/ --glob '*.qml' --glob '*.js' | wc -l` = 0
  (excluding data files where path is a runtime value)
- Greeter background still loads when launched
</verification>

---

### AG3 — Add Error Handling to Unguarded ProcessRunner Instances

<problem>
Three ProcessRunner usages have no error handling: KeyboardLayoutHypr (hyprctl fails silently),
Cava (crash goes unlogged), IdleInhibitor (systemd-inhibit failure unnoticed).
This violates the convention established in `Docs/CodingConventions.md`.
</problem>

<actions>
1. **`Bar/Modules/KeyboardLayoutHypr.qml`** — the `switchProc` ProcessRunner that runs
   `hyprctl switchxkblayout`. Add `onExited` handler:
   ```qml
   onExited: (code, status) => {
       if (code !== 0) console.warn("[KeyboardLayoutHypr] switchxkblayout failed, code:", code)
   }
   ```

2. **`Components/Cava.qml`** — find the ProcessRunner for cava. Add logging to `onExited`:
   ```qml
   onExited: (code, status) => {
       if (code !== 0 && !root._cavaWarned) {
           console.warn("[Cava] cava exited with code", code, "— visualizer unavailable. Install cava for audio spectrum.")
           root._cavaWarned = true
       }
   }
   ```
   Add `property bool _cavaWarned: false` to the root item.

3. **`Helpers/IdleInhibitor.qml`** (or wherever systemd-inhibit is invoked) — add onExited
   warning for non-zero exit.

4. **Verify the HyprlandWatcher socat ProcessRunner** — check if it already logs on failure.
   If not, add a one-time warning for socat unavailability (similar to rsmetrx pattern
   in Connectivity.qml).
</actions>

<verification>
- Launch quickshell without cava installed → stderr shows warning once, not on every restart
- `hyprctl switchxkblayout` failure → logged once
- No regression: widgets still function when tools are available
</verification>

---

### AG4 — Expose Hardcoded Timings as Theme Tokens

<problem>
4 timing values are hardcoded in QML instead of being Theme tokens. This prevents
users from tuning animation/polling behavior through .theme.json.
</problem>

<actions>
1. **Read `Settings/Theme.qml`** — locate the timers section (around line 174 group).

2. **Add tokens** (with defaults matching current hardcoded values):
   ```qml
   property int timerTick2sMs: val('timers.tick2sMs', 2000)
   property int mediaAccentDebounceMs: val('media.accentDebounceMs', 60)
   ```

3. **Replace in source files:**
   - `Services/Timers.qml` line ~51: `2000` → `Theme.timerTick2sMs`
   - `Bar/Modules/Media.qml` line ~92: `60` → `Theme.mediaAccentDebounceMs`

4. **Greeter timings** (300ms auth test, 500ms lock animation) — assess whether these
   should be Theme tokens or remain hardcoded. The greeter has its own visual system
   independent of the main Theme; if it doesn't read Theme.qml, leave as-is with a comment.
</actions>

<verification>
- Default behavior unchanged (same timing values)
- `rg '2000' Services/Timers.qml` → no raw 2000 in timer interval
- Theme tokens appear in `Theme.qml` with correct defaults
</verification>

---

### AG5 — Configurable Network Endpoints

<problem>
Connectivity.qml hardcodes `8.8.8.8` as the ping target. Weather.js hardcodes
`open-meteo.com` API URLs. Users in restricted networks (corporate, China) may need
different endpoints.
</problem>

<actions>
1. **Add Settings properties** (in Settings.json schema and code):
   ```
   networkPingTarget: string, default "8.8.8.8"
   weatherApiBaseUrl: string, default "https://api.open-meteo.com/v1"
   weatherGeoApiBaseUrl: string, default "https://geocoding-api.open-meteo.com/v1"
   ```

2. **Connectivity.qml** — replace hardcoded `8.8.8.8` in the ping command with
   `Settings.settings.networkPingTarget || "8.8.8.8"`.

3. **Weather.js** — replace hardcoded API base URLs with parameters passed from the
   calling QML (Weather.qml service), which reads from Settings.
   Note: Weather.js is a plain JS file imported via `import`. It receives parameters
   in function calls, not through QML bindings. Adjust `fetchWeather()` and
   `fetchCoordinates()` signatures to accept optional base URL parameters.

4. **Update Docs/Config.md** with the new settings.
</actions>

<verification>
- Default behavior unchanged (same endpoints)
- Set `networkPingTarget: "1.1.1.1"` in Settings.json → ping uses new target
- Weather fetching works with default URLs
</verification>

---

### AG6 — System Resource Monitor Widget

<problem>
The bar has no system resource monitoring. Users must open a terminal to check CPU/RAM
usage. A lightweight monitoring capsule would provide at-a-glance system health.
</problem>

<actions>
1. **Create `Services/SystemMonitor.qml`** — singleton service that periodically reads:
   - CPU usage: parse `/proc/stat` via ProcessRunner (`cat /proc/stat` → compute delta)
     OR use `top -bn1 -p0` for single-shot
   - RAM usage: parse `/proc/meminfo` (MemTotal, MemAvailable)
   - Optional: disk usage via `df -h /` (poll less frequently)
   - Optional: CPU temperature via `/sys/class/thermal/thermal_zone0/temp`

   Properties to expose:
   ```qml
   property real cpuPercent: 0       // 0-100
   property real ramPercent: 0       // 0-100
   property real ramUsedGiB: 0
   property real ramTotalGiB: 0
   property real cpuTempCelsius: -1  // -1 = unavailable
   property real diskPercent: -1     // -1 = unavailable
   ```

   Use existing `ProcessRunner` with `parseJson: false` and `onLine` for parsing.
   Poll interval: new Theme token `Theme.systemMonitorPollMs` (default: 3000).

2. **Create `Bar/Modules/SystemMonitorCapsule.qml`** — bar capsule widget:
   - Extends `CapsuleButton` (from Capsule Tower hierarchy)
   - Compact display: `CPU 45% | RAM 8.2G` (or icon-based)
   - Color coding: green < 60%, yellow 60-85%, red > 85% (thresholds as Theme tokens)
   - Tooltip: detailed breakdown (CPU%, RAM used/total, temp if available)
   - Click action: configurable (default: open system monitor app)

3. **Add Theme tokens:**
   ```
   systemMonitorPollMs, systemMonitorCpuWarnPercent, systemMonitorCpuCritPercent,
   systemMonitorRamWarnPercent, systemMonitorRamCritPercent
   ```

4. **Add Settings toggle:** `showSystemMonitor: boolean, default false`

5. **Register in qmldir** files and add to the appropriate panel widget row in Bar.qml.

**Implementation notes:**
- Read `memory/quickshell.md` for the Capsule Tower hierarchy before creating the widget.
- Follow `CenteredCapsuleRow` → `CapsuleButton` → `WidgetCapsule` pattern.
- Use `ConnectivityUi.js` `warningColor()`/`errorColor()` as reference for threshold colors.
- Use `Format.js` for number formatting consistency.
</actions>

<verification>
- Widget appears in bar when `showSystemMonitor: true` in Settings.json
- CPU/RAM percentages update every 3 seconds
- Tooltip shows detailed info
- Hidden by default (no visual change without opt-in)
- No errors in stderr when widget is enabled
</verification>

---

### AG7 — Greeter Theme Integration

<problem>
The greeter/lock screen uses hardcoded colors (`greeter/ShellGlobals.qml` lines 15-21:
`#30c0ffff`, `#50ffffff`, `#25ceffff`, etc.) instead of reading from the Theme system.
This means the greeter never matches the user's desktop theme.
</problem>

<actions>
1. **Assess greeter architecture** — read `greeter/ShellGlobals.qml` and check:
   - Does the greeter import `qs.Settings`? Can it access `Theme`?
   - Does it have its own module system separate from the main bar?
   - What components reference `ShellGlobals.colors`?

2. **If Theme is accessible from the greeter:**
   Add Theme tokens for greeter colors:
   ```qml
   property color greeterBar: val('greeter.bar', "#30c0ffff")
   property color greeterBarOutline: val('greeter.barOutline', "#50ffffff")
   property color greeterWidget: val('greeter.widget', "#25ceffff")
   property color greeterWidgetActive: val('greeter.widgetActive', "#80ceffff")
   ```
   Update ShellGlobals to read from Theme with fallback to current hardcoded values.

3. **If Theme is NOT accessible** (separate Quickshell instance):
   Document this limitation in a comment in ShellGlobals.qml.
   Consider: can the greeter read `.theme.json` directly via FileView?
   If yes, add a lightweight JsonAdapter in the greeter scope.

4. **Verify** that the greeter renders correctly with both the default and a custom theme.
</actions>

<verification>
- Greeter colors match when a non-default theme is applied
- Default appearance unchanged (same defaults as current hardcoded values)
- No crash on greeter launch (test via `quickshell --config greeter` or lock screen trigger)
</verification>

---

### AG8 — Accessibility: Reduced Motion and Theme Toggle

<problem>
Animation disabling is only possible via env var `QS_DISABLE_ANIMATIONS=1`.
There is no Settings.json or Theme toggle. Users with vestibular disorders or
low-powered hardware need an easy way to disable animations.
</problem>

<actions>
1. **Add Settings property:** `reducedMotion: boolean, default false`

2. **Add a computed property in Theme.qml:**
   ```qml
   readonly property bool animationsEnabled: {
       if ((Quickshell.env("QS_DISABLE_ANIMATIONS") || "") === "1") return false;
       if (Settings.settings && Settings.settings.reducedMotion) return false;
       return true;
   }
   ```

3. **Replace existing env var checks** across the codebase:
   - `Components/Spinner.qml` line ~16
   - `Components/PillIndicator.qml` line ~27
   - `Components/LinearSpectrum.qml` line ~28
   Each currently does: `((Quickshell.env("QS_DISABLE_ANIMATIONS") || "") !== "1")`
   Replace with: `Theme.animationsEnabled`

4. **Update existing Behavior guards** — where `enabled: Theme._themeLoaded`, change to:
   `enabled: Theme._themeLoaded && Theme.animationsEnabled`
   This affects: WidgetCapsule, Bar.qml panel Behaviors (seamFillColor, panelTintColor, etc.)

5. **Update Docs/Config.md** with the new setting.
</actions>

<verification>
- Set `reducedMotion: true` → all animations disabled (capsule colors snap, spectrum bars don't animate)
- Set `QS_DISABLE_ANIMATIONS=1` → same effect (backward compatible)
- Both unset → animations work normally
- `rg 'QS_DISABLE_ANIMATIONS' dotfiles/dot_config/quickshell/ --glob '*.qml'` → only Theme.qml
</verification>

---

### AG9 — Diagnostic Overlay Mode

<problem>
Debugging layout, timing, and service health requires reading stderr logs.
A built-in diagnostic overlay would show real-time state directly on screen,
speeding up troubleshooting.
</problem>

<actions>
1. **Add Settings property:** `diagnosticOverlay: boolean, default false`

2. **Create `Components/DiagnosticOverlay.qml`** — a semi-transparent overlay that shows:
   - Active services status: Connectivity (hasLink/hasInternet), rsmetrx running,
     MusicMeta introspectionTool, Weather status
   - Current Theme file path and token count
   - Active ProcessRunner count (how many external processes running)
   - Frame rate / render stats if available from Quickshell API
   - Active QS_* environment overrides
   - Current monitor scale factor

3. **Embed in Bar.qml** (or shell.qml) gated by `Settings.settings.diagnosticOverlay`.
   Position: top-right corner, small font, low opacity background.

4. **Add keyboard shortcut integration** if Quickshell supports global key bindings,
   or document that it's toggled via Settings.json edit + theme reload.

**Implementation notes:**
- This is a developer/power-user feature, off by default.
- Keep it read-only — no interactive controls.
- Use `Column` with `Text` items, monospace font.
- Poll `Timers.tick2s` for refresh.
</actions>

<verification>
- Set `diagnosticOverlay: true` → overlay appears showing service states
- Overlay updates every 2 seconds
- Default: no overlay visible
- Does not intercept mouse events (click-through)
</verification>

---

### AG10 — Enhanced Calendar with Personal Events

<problem>
The Calendar widget shows public holidays (via Holidays.js API) but has no support
for personal calendar events. Many users have `.ics` files or CalDAV subscriptions
(managed by vdirsyncer, which is already in the Salt config).
</problem>

<actions>
1. **Assess feasibility:** Check if vdirsyncer stores `.ics` files locally.
   Common path: `~/.local/share/vdirsyncer/` or `~/.local/share/calendars/`.
   Use `Quickshell.env("XDG_DATA_HOME")` to find the base path.

2. **Create `Helpers/IcsParser.js`** — minimal ICS parser:
   - Parse `BEGIN:VEVENT` / `END:VEVENT` blocks
   - Extract `DTSTART`, `DTEND`, `SUMMARY`, `DESCRIPTION`
   - Handle `DTSTART;VALUE=DATE:20260302` (all-day) and `DTSTART:20260302T150000Z` (timed)
   - Return array of `{ date, endDate, summary, description, allDay }` objects
   - No RRULE support in v1 (too complex) — only explicit events

3. **Create `Services/CalendarEvents.qml`** — service that:
   - Watches calendar directory via FileView (if Quickshell supports directory watch)
   - OR polls via ProcessRunner: `find ~/.local/share/calendars -name '*.ics' -newer /tmp/.qs-cal-stamp`
   - Exposes: `property var eventsForDate: ({})` — map of date string → event array
   - Method: `getEventsForDate(dateString)` returning event list

4. **Integrate with Calendar.qml** — add event indicators (dots) on dates with events.
   Show event summaries in tooltip or expanded view.

5. **Add Settings:**
   ```
   calendarEventsEnabled: boolean, default false
   calendarEventsPath: string, default "" (auto-detect from XDG_DATA_HOME)
   ```

**Constraints:**
- ICS parsing is best-effort; don't fail on malformed files.
- Keep the parser under 100 lines — this is not a full RFC 5545 implementation.
- If no calendar files found, silently degrade (no errors, no indicators).
</actions>

<verification>
- With `.ics` files present → dots appear on calendar dates
- Without `.ics` files → calendar unchanged (no errors)
- Tooltip/expansion shows event summaries
- Default: feature disabled, no filesystem access
</verification>

---

### AG11 — Quick Settings Panel

<problem>
Common system toggles (WiFi, Bluetooth, Do-Not-Disturb) require opening external
applications. A quick-settings panel accessible from the bar would reduce friction.
</problem>

<actions>
1. **Create `Widgets/SidePanel/QuickSettings.qml`** — side panel with toggle rows:
   - **WiFi toggle**: `nmcli radio wifi on/off` via ProcessRunner
   - **Bluetooth toggle**: `bluetoothctl power on/off` via ProcessRunner
   - **Do-Not-Disturb**: internal flag that suppresses MusicPopup toasts
   - **Night light**: `gammastep` / `wlsunset` toggle (if installed)
   - **Screen brightness**: slider using `brightnessctl` (if installed)

2. **Create `Bar/Modules/QuickSettingsButton.qml`** — bar capsule that toggles the panel.
   Icon: "settings" or "tune" (Material icon).

3. **Create `Services/SystemToggles.qml`** — singleton exposing:
   ```qml
   property bool wifiEnabled: true
   property bool bluetoothEnabled: false
   property bool dndEnabled: false
   property bool nightLightEnabled: false
   property real brightness: 1.0
   ```
   Each property backed by ProcessRunner polling + toggle methods.
   **Resilience**: each toggle checks tool availability on first use; if missing,
   the row shows "unavailable" and disables interaction.

4. **Add Settings:** `showQuickSettings: boolean, default false`

5. **Add Theme tokens** for quick-settings panel styling (reuse existing sidePanel tokens
   where possible).

**Implementation notes:**
- Read existing `Widgets/SidePanel/Music.qml` and `Weather.qml` for panel patterns.
- Use `CapsuleButton` for toggles within the panel.
- Each toggle should be independently hideable via Settings.
- Poll states infrequently (every 5-10s) to avoid battery drain.
</actions>

<verification>
- Panel opens when button is clicked
- WiFi toggle works if nmcli is available; shows "unavailable" if not
- DND suppresses music toasts
- Default: hidden (opt-in)
</verification>

---

### AG12 — Notification Center

<problem>
Currently only MusicPopup provides toast-style notifications. There's no
notification history, no persistent notification area, and no integration
with the freedesktop notification spec beyond MPRIS.
</problem>

<actions>
1. **Assess Quickshell notification API** — check if Quickshell exposes
   `org.freedesktop.Notifications` or a notification model. Check:
   ```bash
   rg -i 'notification' dotfiles/dot_config/quickshell/ --glob '*.qml'
   ```
   The greeter has `notifications/` — examine its implementation for reuse.

2. **If Quickshell provides notification access:**
   - Create `Services/NotificationManager.qml` — singleton tracking notification history
   - Expose: `property var notifications: []` (last N notifications),
     `property int unreadCount: 0`, `function dismiss(id)`, `function clear()`
   - Create `Widgets/SidePanel/Notifications.qml` — scrollable list panel
   - Create `Bar/Modules/NotificationBadge.qml` — capsule showing unread count,
     opens notification panel on click

3. **If Quickshell does NOT provide notification access:**
   - Document the limitation
   - Consider: can we listen to D-Bus via ProcessRunner + `dbus-monitor`?
   - Minimal viable: parse `dunstctl history` output (if dunst is used)
   - Or create a thin proxy script that sits on the notification bus

4. **Add Settings:**
   ```
   showNotificationCenter: boolean, default false
   notificationHistorySize: integer, default 50
   notificationDndEnabled: boolean, default false
   ```

**Constraints:**
- If the notification bus is unavailable, degrade silently.
- Notification panel should reuse existing SidePanel styling.
- History is in-memory only (clears on restart) — no persistent storage.
</actions>

<verification>
- Sending `notify-send "test"` → notification appears in panel
- Badge shows unread count
- DND mode suppresses popups but still logs to history
- Default: hidden
</verification>

---

## Execution Plan

<execution-order>
Priority and dependency order:

**Phase 1 — Correctness & Documentation (no UX changes)**
1. AG1: Complete Settings schema
2. AG2: Fix hardcoded paths
3. AG3: Add missing error handling
4. AG4: Expose hardcoded timings

**Phase 2 — Configuration & Resilience**
5. AG5: Configurable network endpoints
6. AG8: Accessibility reduced-motion toggle

**Phase 3 — UX Polish**
7. AG7: Greeter theme integration
8. AG9: Diagnostic overlay

**Phase 4 — New Features (each independent)**
9. AG6: System resource monitor
10. AG10: Calendar events
11. AG11: Quick settings panel
12. AG12: Notification center

Phases 1-2 are the highest priority and lowest risk.
Phase 3 improves existing functionality.
Phase 4 items are independent — implement in any order, skip any if scope is too large.
</execution-order>

---

## Constraints

<constraints>
- **Backward compatibility**: all existing Settings.json and .theme.json must work unchanged.
- **Graceful degradation**: missing tools (cava, rsmetrx, nmcli, brightnessctl) must not
  cause errors — log once, degrade to "unavailable" state.
- **Performance**: new polling services must respect battery/CPU. Default poll intervals ≥ 2s.
  New features must be opt-in (hidden by default).
- **No external dependencies**: only use tools commonly found on Arch-based systems
  (coreutils, iproute2, nmcli, bluetoothctl, brightnessctl, etc.).
- **Code conventions**: follow `Docs/CodingConventions.md` exactly — property naming,
  error handling categories, Theme token format, import style.
- **Commit style**: `[quickshell] imperative description` per `CLAUDE.md`.
- **Testing**: after each AG, verify quickshell starts without errors and the bar renders.
  For new widgets, verify they appear only when opted in via Settings.
- **Documentation**: every new Setting must appear in both SettingsSchema.json and Config.md.
  Every new Theme token must follow `val('dotted.path', default)` convention.
</constraints>

---

## Chain-of-Verification Checklist

<verification-final>
After all Action Groups are complete, run these checks:

```bash
# No empty catch blocks
rg 'catch\s*\([^)]*\)\s*\{\s*\}' dotfiles/dot_config/quickshell/ --glob '*.js' --glob '*.qml' | wc -l
# Expected: 0

# No hardcoded user paths in code
rg '/home/[^/]+' dotfiles/dot_config/quickshell/ --glob '*.qml' --glob '*.js' | wc -l
# Expected: 0 (or only in data files)

# Settings schema covers all used settings
# (manual: compare rg output to schema entries)

# All new features hidden by default
rg 'default.*true' Docs/SettingsSchema.json
# New features should NOT appear here (all default false)

# No raw QS_DISABLE_ANIMATIONS outside Theme.qml
rg 'QS_DISABLE_ANIMATIONS' dotfiles/dot_config/quickshell/ --glob '*.qml' | grep -v Theme.qml | wc -l
# Expected: 0 (after AG8)

# Quickshell starts without errors
quickshell 2>&1 | head -20
# Expected: no errors/warnings beyond expected service unavailability
```
</verification-final>
