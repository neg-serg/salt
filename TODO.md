# TODO

## Music analysis pipeline (essentia + annoy)

Scripts `music-highlevel`, `music-similar`, `music-index` require:
- `essentia` (provides `streaming_extractor_music`) — not in Arch repos, needs AUR or custom PKGBUILD
- `python-annoy` — approximate nearest neighbors library, pip or AUR

Create a dedicated Salt state (`music_analysis.sls` or extend `installers.sls`) that:
1. Builds/installs `essentia` via paru or PKGBUILD
2. Installs `python-annoy` via pip_pkg macro
3. Guards both with idempotency checks


## ProxyPilot: Google Cloud TOS violation

Google Cloud account (`serg.zorg@gmail.com`) is TOS-blocked on Cloud Code API.
Gemini and Antigravity tokens authenticate but all API requests return 403 PERMISSION_DENIED.

**Status (v0.3.0-dev-0.40)**:
- `tui` flag panic: **fixed** in v0.3.0-dev-0.40
- `--claude-login`: **works** — native Claude OAuth via Anthropic (not Google)
- `--antigravity-login` / `--login` (Gemini): authenticate successfully but API calls fail (TOS block)
- Appeal form: https://forms.gle/hGzM9MEUv2azZsrb9

**Current routing**: Claude models use native OAuth token. Gemini/Antigravity routes are dead until TOS appeal is resolved.

- Binary: `~/.local/bin/proxypilot` v0.3.0-dev-0.40
- Config: `~/.config/proxypilot/config.yaml`
- Repo: https://github.com/Finesssee/ProxyPilot


## ydotool service not enabled

`ydotool.service` (systemd user unit) is installed but **disabled and inactive**.
Hyprland MCP tools (`mouse_click`, `click_text`, `key_press`, etc.) depend on `ydotoold` running.

**Fix**: Enable the user service in Salt (`user_services.sls` or similar):
```
systemctl --user enable --now ydotool.service
```

Without this, the Hyprland MCP server's mouse/keyboard automation tools fail silently or error on click/type operations. Screenshots still work (they use `grim`/`slurp`, not ydotool).


## OpenClaw: cosmetic improvements

**npmrc prefix**: npm global prefix is set to `/nonexistent` (from `/etc/npmrc`).
Create `~/.npmrc` with `prefix=$HOME/.local` via chezmoi (`dotfiles/dot_npmrc`).
Without this, `npm list -g` and `npm outdated -g` fail (Salt install works around it via `--prefix`).

**user_services.yaml**: `openclaw-gateway.service` is managed directly from `openclaw_agent.sls` but not registered in `data/user_services.yaml`. For consistency, consider moving `user_service_file` + `user_service_enable` there, keeping only npm install and config in `openclaw_agent.sls`.

**ProxyPilot alias comment**: the `name/alias` format in `proxypilot.yaml.j2` is not self-explanatory. Add a comment clarifying the mapping direction (alias = what the client sends, name = local model ID).


## Nyxt browser packaging

`nyxt-bin` — binary packaging for the Nyxt browser. Needs investigation:
current AUR package may be sufficient, or may need custom PKGBUILD.
