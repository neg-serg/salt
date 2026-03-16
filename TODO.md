# TODO

Backlog of ideas and improvements. When ready to implement, run `/speckit.specify` with the description.

---

## Browser profiles with persistent sessions

Multiple Floorp profiles with persistent data (cookies, localStorage, sessions). Goal: login to VK, YouTube and other popular sites via cookie import from other browsers.

- Named profiles with isolated storage
- Cookie import/export between profiles and browsers (Chrome, Firefox, Floorp)
- Profile switching via CLI or Hyprland keybind
- Salt-managed profile templates with pre-configured settings (extensions, privacy, proxy)
- Consider: `browser-cookie3` (Python) for cross-browser cookie extraction

---

## Music analysis pipeline (essentia + annoy)

Scripts `music-highlevel`, `music-similar`, `music-index` require:
- `essentia` (provides `streaming_extractor_music`) — not in Arch repos, needs AUR or custom PKGBUILD
- `python-annoy` — approximate nearest neighbors library, pip or AUR

Create a dedicated Salt state (`music_analysis.sls` or extend `installers.sls`) that:
1. Builds/installs `essentia` via paru or PKGBUILD
2. Installs `python-annoy` via pip_pkg macro
3. Guards both with idempotency checks


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


## Home LLM cluster — exo / llama.cpp RPC

When building a multi-node home cluster, evaluate distributed LLM inference options:

- **[exo](https://github.com/exo-explore/exo)** (~42k stars) — P2P cluster, auto-discovery via libp2p, auto-sharding across heterogeneous devices. AMD ROCm supported via tinygrad. No AUR package (pip-only). OpenAI-compatible API — plugs into ProxyPilot. Best for: models >VRAM (70B–235B class).
- **llama.cpp RPC backend** — already installed (`llama.cpp-vulkan`). Run `rpc-server` on remote nodes, connect via `--rpc host:50052`. No extra dependencies. Vulkan support. Best for: extending existing stack with minimal overhead.
- **Ollama cluster mode** — in development upstream, may land before cluster is built. Monitor progress.

Decision: prefer llama.cpp RPC (already in stack, AUR package, Vulkan). Revisit exo when AMD ROCm support matures and/or AUR package appears.


## SaluteSpeech — STT/TTS evaluation

Evaluate [SaluteSpeech](https://developers.sber.ru/docs/ru/salutespeech/overview) (Sber) for Russian-language speech recognition (STT) and synthesis (TTS).

- Freemium: ~1000 min/mo STT free tier
- Compare with local alternatives: `faster-whisper` (large-v3), Vosk
- Decision: cloud API (SaluteSpeech) vs self-hosted (Whisper on GPU)
- If adopted: Salt state for setup, API key in gopass, systemd service
