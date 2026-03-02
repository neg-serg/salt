# Coding Conventions

Quickshell QML/JS coding standards observed across the codebase.

## Property Naming

| Pattern | Use | Example |
|---|---|---|
| `camelCase` | Public properties | `barHeightPx`, `seamWidth` |
| `_camelCase` | Private/internal properties | `_themeLoaded`, `_pendingLines` |
| `isXxx` / `hasXxx` | Boolean state queries | `isPlaying`, `hasLink` |
| `xxxEnabled` | Boolean feature flags | `stdinEnabled`, `panelTintEnabled` |
| `xxxMode` | String enum properties | `restartMode` |
| `xxxMs` | Duration in milliseconds | `backoffMs`, `debounceMs` |
| `xxxPx` | Dimension in pixels | `barHeightPx`, `seamTintTopInsetPx` |

## Imports

- QML modules: `import qs.Components`, `import qs.Settings`
- JS helpers: `import "../Helpers/Color.js" as Color`
- Local modules: `import "Modules" as LocalMods`
- Singleton access: `Theme.property`, `Settings.settings.property`

## Error Handling

- **Structural catches** (JSON parse failures, process init) — use `console.warn("[Module.function]", e)`
- **Field-extraction catches** (metadata parsing, optional fields) — use descriptive comment: `/* metadata field unavailable */`
- **Intentional fallbacks** (Qt.include, header-setting, fire-and-forget) — use descriptive comment: `/* header API unavailable */`
- Never leave catch blocks empty

## Theme Tokens

All configurable values go through `Theme.qml` via `val('dotted.path', default)`.

- Colors: `property color panelTintColor: val('panel.tint.color', "#ff2a36")`
- Dimensions: `property int panelHeight: val('panel.height', 22)`
- Ratios: `property real panelInterWidgetRatio: val('panel.interWidgetRatio', 1.35)`
- Scale-dependent values computed at use site: `Math.round(Theme.panelHeight * s)`

## Animation Tokens

Six reusable Behavior components in `Components/`:

| Component | Duration | Easing |
|---|---|---|
| `ColorFastInOutBehavior` | `panelAnimFastMs` (200) | `uiEasingInOut` |
| `NumberFadeBehavior` | `uiAnimQuickMs` | `uiEasingQuick` |
| `NumberStdOutBehavior` | `panelAnimStdMs` (250) | `uiEasingStdOut` |

Guard with `enabled: Theme._themeLoaded` to prevent animation on initial load.

## Shared Helpers

- `Color.js` — color math: `mix`, `withAlpha`, `contrastOn`, `saturate`, `desaturate`
- `Utils.js` — `clamp`, `clamp01`, `coerceInt`, `computedInlineFontPx`
- `Format.js` — text formatting, `colorCss`
- `WidgetBg.js` — per-widget background color resolution from Settings

Prefer shared helpers over local reimplementations. If a helper is used in 2+ files, it belongs in `Helpers/`.

## QML Component Patterns

- Singletons declared in `qmldir` — do not instantiate, access directly
- `ProcessRunner` for external process execution (streaming or poll JSON)
- `WidgetCapsule` as base for all bar capsule widgets
- `Connections` with `ignoreUnknownSignals: true` for dynamic signal binding
