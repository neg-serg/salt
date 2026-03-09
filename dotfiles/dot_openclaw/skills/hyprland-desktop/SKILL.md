---
name: hyprland-desktop
description: Control Hyprland desktop — workspaces, windows, screenshots, app launching
requires:
  bins: ["hyprctl", "grim"]
allowed-tools:
  - "Bash(hyprctl:*)"
  - "Bash(grim:*)"
  - "Bash(slurp:*)"
os: ["linux"]
---

# Hyprland Desktop Control

## Availability Check

Before running any command, verify that Hyprland is running and the IPC socket is reachable:

```bash
hyprctl version
```

If this fails, Hyprland is not running or the socket is unavailable. Inform the user and do not attempt further commands.

## Workspace Management

List all workspaces (JSON output with id, name, monitor, windows count):

```bash
hyprctl workspaces -j
```

Get the currently active workspace:

```bash
hyprctl activeworkspace -j
```

Switch to a specific workspace by number:

```bash
hyprctl dispatch workspace N
```

## Window Management

List all windows (JSON output includes title, class, workspace, position, size):

```bash
hyprctl clients -j
```

Focus a window by title pattern or address:

```bash
hyprctl dispatch focuswindow "title:PATTERN"
```

Close a window gracefully:

```bash
hyprctl dispatch closewindow "title:PATTERN"
```

Move a window to a different workspace:

```bash
hyprctl dispatch movetoworkspace N,title:PATTERN
```

Resize the active window (X and Y are pixel deltas, can be negative):

```bash
hyprctl dispatch resizeactive X Y
```

Toggle fullscreen for the active window:

```bash
hyprctl dispatch fullscreen 0
```

Toggle floating mode for the active window:

```bash
hyprctl dispatch togglefloating
```

## App Launching

Launch an application via Hyprland's exec dispatcher:

```bash
hyprctl dispatch exec -- COMMAND
```

Examples:

```bash
hyprctl dispatch exec -- kitty
hyprctl dispatch exec -- floorp
```

## Screenshots

Capture the full screen:

```bash
grim /tmp/openclaw-screenshot-$(date +%s).png
```

Capture a user-selected region (interactive selection):

```bash
grim -g "$(slurp)" /tmp/openclaw-screenshot-$(date +%s).png
```

Capture a specific window by its geometry. First, find the window geometry from `hyprctl clients -j`, then capture it:

```bash
grim -g "X,Y WxH" /tmp/openclaw-screenshot.png
```

## Monitor Info

Get monitor details (resolution, scale, position, active workspace):

```bash
hyprctl monitors -j
```

## Safety Rules

- ALWAYS confirm with the user before closing windows — unsaved data may be lost.
- NEVER kill processes directly. Use `hyprctl dispatch closewindow` which sends a graceful close request to the application.
- When switching workspaces, first check what windows are on the target workspace with `hyprctl clients -j` and inform the user.
- Screenshot files go to `/tmp/` only. Never write to user directories without explicit permission.
