# TODO

## Music analysis pipeline (essentia + annoy)

Scripts `music-highlevel`, `music-similar`, `music-index` require:
- `essentia` (provides `streaming_extractor_music`) — not in Arch repos, needs AUR or custom PKGBUILD
- `python-annoy` — approximate nearest neighbors library, pip or AUR

Create a dedicated Salt state (`music_analysis.sls` or extend `installers.sls`) that:
1. Builds/installs `essentia` via paru or PKGBUILD
2. Installs `python-annoy` via pip_pkg macro
3. Guards both with idempotency checks


## ProxyPilot: Claude OAuth broken + tui flag panic

`proxypilot --claude-login` — OAuth callback never completes (token not saved to `~/.cli-proxy-api/`).
`proxypilot --help` and all `--*-login` flags panic with `flag redefined: tui`.
Gemini and Antigravity OAuth work fine (tokens added manually before the bug appeared).

**Workaround**: Claude models available through Antigravity provider (`claude-sonnet-4-6`, `claude-opus-4-6-thinking`).
Developer tools stay proxied (Claude Code/OpenCode configs + `claude-proxy` wrapper), while the stock `claude` CLI now uses Anthropic directly.

- Binary: `~/.local/bin/proxypilot` v0.3.0-dev-0.39 (latest release still has the tui flag bug)
- Config: `~/.config/proxypilot/config.yaml`
- Repo: https://github.com/Finesssee/ProxyPilot
- Re-test `--claude-login` and `--gemini-cli-login` after next ProxyPilot release


## Nyxt browser packaging

`nyxt-bin` — binary packaging for the Nyxt browser. Needs investigation:
current AUR package may be sufficient, or may need custom PKGBUILD.
