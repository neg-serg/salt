# NixOS Package Inventory — Remaining Items

Packages from `~/src/nixos-config/` **not yet migrated** to the Fedora Atomic workstation.
Already-migrated (`[x]`) and Nix-specific (`[-]`) items have been removed.
See [nix-only-utilities.md](nix-only-utilities.md) for the detailed plan on each item.

---

## CLI — Archives

- [ ] pzip — parallel zip; not packaged for Fedora

## CLI — Media

- [ ] asciinema-agg — GIF renderer for asciinema; not installed

## CLI — Monitoring

- [ ] below (opt) — BPF-based time-traveling monitor; not installed

## Development — Python

_All items removed — not needed on Fedora (beautifulsoup4, pynvim, fontforge, fonttools)._

## Development — Misc

- [ ] opencode (opt) — AI coding agent; not installed

## System — Boot

- [ ] sbctl — Secure Boot debugging; not installed

## System — VPN

- [ ] update-resolv-conf — OpenVPN DNS helper; check if packaged
- [ ] throne (opt) — VPN proxy; not installed
- [ ] xray — VLESS proxy core; not installed
- [ ] sing-box — universal proxy; not installed

## System — Hardware General

- [ ] overskride (opt) — Bluetooth OBEX client; not installed
- [ ] wirelesstools (opt) — iwconfig helpers; not installed

## System — Hardware Video

- [ ] read-edid — monitor EDID reader; not installed

## System — Hardware Misc

- [ ] qmk-udev-rules — QMK keyboard rules; not installed as RPM
- [ ] droidcam — phone as webcam; not installed

## Monitoring

- [ ] dool — dstat replacement; not in RPMs
- [ ] turbostat — kernel tool; not installed separately
- [ ] adguardian — AdGuard Home terminal dashboard; not installed

## Media — Audio Core

- [ ] patchmatrix — LV2/JACK matrix; not installed

## Media — Audio Apps

- [ ] dr14_tmeter — dynamic range measurement; not installed
- [ ] essentia-extractor — audio feature extractor; not installed
- [ ] opensoundmeter (opt) — FFT analysis; not installed
- [ ] roomeqwizard (opt) — acoustic measurement; not installed
- [ ] unflac — FLAC cuesheet converter; not installed
- [ ] cider (opt) — Apple Music player; not installed
- [ ] scdl — SoundCloud downloader; not installed
- [ ] spotify-tui (opt) — TUI Spotify; not installed

## Media — Audio Creation

- [ ] supercolliderPlugins.sc3-plugins — not installed

## Media — Audio DSP

- [ ] brutefir — digital convolution engine; not installed
- [ ] camilladsp — flexible audio DSP; not installed
- [ ] jamesdsp — audio effect processor; not installed
- [ ] yabridge — VST bridge; not installed
- [ ] yabridgectl — yabridge CLI; not installed

## Media — Multimedia

- [ ] media-player-info — udev HW database; check if installed
- [ ] mpvc — mpv TUI controller; not installed

## Media — AI Upscale

- [ ] realesrgan-ncnn-vulkan (opt) — GPU upscaler; not installed

## Media — Spotifyd

- [ ] spotifyd — Spotify daemon; not installed

## Session — Theme & Wallpaper

- [ ] matugen-themes — template pack; check if bundled

## Session — Chat

- [ ] tdl — Telegram CLI uploader; not installed

## Session — Utils

- [ ] espanso (opt) — text expansion; not installed
- [ ] handlr — xdg-open replacement; TODO: cargo install handlr-regex

## User — GUI Packages

- [ ] rofi-systemd — systemd picker for rofi; not installed

## User — Fonts & Theming

- [ ] oldschool-pc-font-pack — retro PC fonts; not installed

## User — Mail

- [ ] himalaya — async email CLI; not installed

## Games — Launchers & Proton

- [ ] protonplus — Proton prefix manager; not installed

---

## `nix run` Aliases (On-Demand)

| Alias | Description | Status |
|-------|-------------|--------|
| `sk` | two_percent (custom tool) | Not available |
| `newsraft` | RSS reader | Not installed |

## Custom NixOS Packages (Remaining)

| Package | Description | Status |
|---------|-------------|--------|
| neg.tws (opt) | Interactive Brokers TWS | Not installed |

## Flake Inputs (Remaining)

| Input | Purpose | Status |
|-------|---------|--------|
| hy3 | Hyprland i3-like layout plugin | Not installed |
| winapps | Windows apps in KVM | Not set up |
| tailray | Tailscale + xray integration | Not installed |
