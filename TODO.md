# TODO

## Music analysis pipeline (essentia + annoy)

Scripts `music-highlevel`, `music-similar`, `music-index` require:
- `essentia` (provides `streaming_extractor_music`) — not in Arch repos, needs AUR or custom PKGBUILD
- `python-annoy` — approximate nearest neighbors library, pip or AUR

Create a dedicated Salt state (`music_analysis.sls` or extend `installers.sls`) that:
1. Builds/installs `essentia` via paru or PKGBUILD
2. Installs `python-annoy` via pip_pkg macro
3. Guards both with idempotency checks


## ProxyPilot: Claude OAuth broken

`proxypilot -claude-login` — OAuth callback never completes (token not saved to `~/.cli-proxy-api/`).
Gemini OAuth works fine. Re-test after ProxyPilot update.

- Binary: `~/.local/bin/proxypilot` (built from source, fixed duplicate `tui` flag registration)
- Config: `~/.config/proxypilot/config.yaml`
- Repo: https://github.com/Finesssee/ProxyPilot


## Nyxt browser packaging

`nyxt-bin` — binary packaging for the Nyxt browser. Needs investigation:
current AUR package may be sufficient, or may need custom PKGBUILD.
