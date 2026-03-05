# TidalCycles Live Coding Setup

TidalCycles environment for live coding music patterns from Neovim.
Managed by Salt state (`tidal.sls`) with a feature gate — disabled by default.

## Architecture

```
Neovim (.tidal file)
  → tidal.nvim sends code → GHCi REPL (haskell-tidal + BootTidal.hs)
    → OSC over UDP :57120 → SuperCollider (scsynth + SuperDirt)
      → PipeWire (JACK compat) → speakers / DAW
```

## Components

| Component | Package | Version | Source |
|---|---|---|---|
| SuperCollider (audio engine) | `supercollider` | 3.14.x | pacman |
| SC3 Plugins (extra UGens) | `sc3-plugins` | 3.13.x | pacman |
| GHC (Haskell compiler/REPL) | `ghc` | 9.6.x | pacman |
| Tidal library | `haskell-tidal` | 1.9.5 | pacman |
| Tidal Link (Ableton Link) | `haskell-tidal-link` | 1.0.x | pacman (auto-dep) |
| SuperDirt (synths + samples) | Quark | v1.7.4 | Codeberg |
| Dirt-Samples (~396MB) | Quark dependency | — | Codeberg |
| Neovim plugin | `grddavies/tidal.nvim` | latest | lazy.nvim |

## Quick Start

### 1. Enable the feature

In `states/data/hosts.yaml`, set `tidal: true` for your host:

```yaml
hosts:
  your-host:
    features:
      tidal: true
```

### 2. Apply Salt state

```bash
just
# or directly:
salt-call state.apply tidal
```

First run installs packages and downloads SuperDirt + Dirt-Samples (~400MB).
This takes 1-2 minutes depending on network speed.

### 3. Launch TidalCycles

```bash
tidal-start
```

This opens Neovim with a scratch `.tidal` file at `~/music/tidal/scratch.tidal`.

### 4. Start the audio stack (inside Neovim)

```
:TidalLaunch
```

This starts both sclang (SuperCollider) and ghci (Tidal REPL) in Neovim terminal splits.
Wait for `*** SuperDirt started ***` in the sclang output before evaluating patterns.

### 5. Write and evaluate patterns

```haskell
d1 $ sound "bd sn"
```

Place cursor on the line and press `Shift+Enter` to evaluate.

## Keybindings (tidal.nvim defaults)

| Key | Mode | Action |
|---|---|---|
| `Shift+Enter` | Normal/Insert | Evaluate current line |
| `Shift+Enter` | Visual | Evaluate selection |
| `Alt+Enter` | Normal/Insert/Visual | Evaluate current block |
| `<leader>Enter` | Normal | Evaluate treesitter node |
| `<leader>d` | Normal | Silence current channel |
| `<leader>Esc` | Normal | Hush — silence all channels |

## Neovim Commands

| Command | Action |
|---|---|
| `:TidalLaunch` | Start sclang + ghci (full stack) |
| `:TidalQuit` | Stop both processes |

## File Locations

| File | Purpose |
|---|---|
| `~/.config/SuperCollider/startup.scd` | Auto-boots SuperDirt on sclang start (Salt-managed) |
| `/usr/share/haskell-tidal/BootTidal.hs` | Tidal boot script (pacman-managed) |
| `~/.local/share/SuperCollider/downloaded-quarks/` | SuperDirt quark + Dirt-Samples |
| `~/music/tidal/scratch.tidal` | Default scratch file (created by `tidal-start`) |

## Salt State Details

**State file:** `states/tidal.sls`
**Feature flag:** `host.features.tidal` (boolean)
**Default:** `false`

States:
1. `install_supercollider` — pacman install
2. `install_sc3_plugins` — pacman install
3. `install_ghc` — pacman install
4. `install_haskell_tidal` — pacman install (pulls haskell-tidal-link)
5. `superdirt_quark_install` — headless sclang script with `QT_QPA_PLATFORM=offscreen`
6. `superdirt_startup_config` — deploys `startup.scd`

Idempotency guards:
- Package installs: `unless: rg -qx 'pkg' {{ pkg_list }}`
- SuperDirt quark: `creates: ~/.local/share/SuperCollider/downloaded-quarks/SuperDirt`

## Troubleshooting

### No sound after :TidalLaunch

1. Check the sclang terminal split — look for `*** SuperDirt started ***`
2. If SuperDirt didn't start, check PipeWire: `pw-cli ls Node | grep -i jack`
3. Ensure `pipewire-jack` is installed (should be via `audio.sls`)

### sclang crashes on launch

SuperCollider needs a running PipeWire/JACK server. Verify:

```bash
pw-jack jack_lsp
```

If no output, restart PipeWire: `systemctl --user restart pipewire wireplumber`

### Quark install fails during Salt apply

The SuperDirt install requires network access to Codeberg. If behind a proxy or firewall:
- The state retries 3 times with 10s intervals
- Timeout is 1200s (20 minutes)
- Check connectivity: `curl -sSI https://codeberg.org`

### Pattern evaluates but no audio

Check OSC target port — Tidal sends to UDP 57120, SuperDirt listens there:

```bash
ss -ulnp | grep 57120
```

If nothing listens on 57120, SuperDirt didn't start. Restart sclang via `:TidalQuit` then `:TidalLaunch`.
