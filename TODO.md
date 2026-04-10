# TODO

Backlog of ideas and improvements. When ready to implement, run `/speckit.specify` with the description.

---

## OpenCode Telegram Bots (opencode-telegram-bot + telecode)

Salt state `opencode_telegram.sls` created and validated. Binaries install, unit files deploy.
Services are guarded — won't start until Telegram bot tokens are provided.

**Pending (Telegram-side):**
- [ ] Create Telegram bot via @BotFather for opencode-telegram-bot → `gopass insert api/opencode-telegram-bot`
- [ ] Create Telegram bot via @BotFather for telecode → `gopass insert api/telecode-telegram`
- [ ] Run `just apply opencode_telegram` after adding tokens
- [ ] Verify both services start: `systemctl --user status opencode-telegram-bot telecode opencode-serve`

**Optional enhancements:**
- [ ] Add more workspaces to telecode config (currently only `~/src/salt`)
- [ ] Configure STT (voice transcription) for opencode-telegram-bot
- [ ] Add telecode to `salt-monitor` health checks

---

## Full HD Video Generation (LTX 2.3 22B)

LTX 2.3 22B distilled FP8 works on 7900 XTX (24GB, `--lowvram`). Tested: 512x320, 9 frames, 6 steps → 310s.
Goal: Full HD (1920x1080) at maximum quality.

**gen-video CLI integration:**
- [ ] Update `generate.sh` for UNETLoader + DualCLIPLoader (Gemma FP4 + text_projection) + VAELoader — current code hardcoded for CheckpointLoaderSimple
- [ ] Add `--lowvram` to ComfyUI startup when model needs it
- [ ] Add `__MODEL_FILE__`, `__STEPS__` placeholder substitution
- [ ] Update default model to `ltx-23-distilled-fp8`
- [ ] Add 1080p (1920x1080) and 720p (1280x720) resolution presets

**Quality parameters:**
- [ ] Steps: 8 (distilled optimal: 4-8)
- [ ] Test CFG 3.0-5.0 for best quality
- [ ] Width/height must be divisible by 32, frames = 8N+1 (9, 17, 25, 33...)

**Resolution testing (ascending VRAM):**
1. 854x480 (480p) — baseline
2. 1280x720 (720p) — likely fits
3. 1920x1080 (1080p) — may OOM, test carefully

**i2v workflow:**
- [ ] Create `ltx23-distilled-i2v.json` (LoadImage + VAEEncode instead of EmptyLTXVLatentVideo)

**Salt state updates:**
- [ ] Gemma FP4 + text_projection + LTX23 VAE download states
- [ ] GGUF pip deps state (gguf, sentencepiece, protobuf)
- [ ] tokenizer.model download state
- [ ] Workflow deployment for ltx23-distilled-t2v.json

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


## tg-cli: register own Telegram API credentials

`tg-cli` (pipx, `kabi-tg-cli`) is installed and working with default Telegram Desktop credentials (`api_id=2040`).
This increases the risk of account restrictions from Telegram.

- [ ] Register own app at https://my.telegram.org/apps (requires SMS/Telegram code)
- [ ] Create `~/.config/tg-cli/.env` with `TG_API_ID` and `TG_API_HASH`
- [ ] Re-authenticate: `tg status` (will pick up new credentials)
- [ ] Optionally: store credentials in gopass (`api/telegram-api`)

Note: my.telegram.org form may silently reject — known issue, retry later or from a different browser/IP.


## SaluteSpeech — STT/TTS evaluation

Evaluate [SaluteSpeech](https://developers.sber.ru/docs/ru/salutespeech/overview) (Sber) for Russian-language speech recognition (STT) and synthesis (TTS).

- Freemium: ~1000 min/mo STT free tier
- Compare with local alternatives: `faster-whisper` (large-v3), Vosk
- Decision: cloud API (SaluteSpeech) vs self-hosted (Whisper on GPU)
- If adopted: Salt state for setup, API key in gopass, systemd service


## Verify end-to-end alert pipeline for containerized services (FR-016)

After the containerization feature (087-containerize-services) lands, verify FR-016's promise that container failures surface through the existing Loki/Grafana/`monitoring_alerts.sls` stack. Procedure: stop a containerized service (e.g. loki container), wait for the alert timeout, confirm an alert appears through the existing channel. The chain works by construction (Quadlet → systemd journal → Promtail → Loki → Grafana → monitoring_alerts), but has not been exercised end-to-end. Low priority — deferred from the 087 spec analysis session (finding L1).

- [ ] Stop a containerized service after cutover and confirm alert fires through the existing channel
- [ ] Record outcome in 087 post-cutover notes


## wl-daemon: reconnect-on-broken-pipe instead of graceful shutdown

When the Wayland compositor emits a fast output-remove-and-readd sequence (monitor hotplug, mode change, `hyprctl reload`, DPMS cycle), `wl-daemon` can race a pending `wl_display_flush()` against the now-closed `wl_output`. The flush returns `EPIPE` (Broken pipe), the error propagates as `wayland flush error` to the main loop, and the daemon currently chooses to `shutting down` cleanly (exit status 0). Observed 2026-04-10 at 20:18:01 on telfir after a DP-2 reconfigure — prior commit 4bb90eb (fix double-free on shutdown during wallpaper transition) converted what used to be SIGABRT into a clean exit, which exposed this handling gap.

The immediate symptom (no wallpaper until manual restart) was mitigated by switching `wl.service` to `Restart=always` + `StartLimitBurst=5/60s` — systemd now bounces the daemon automatically, and the rate limit prevents loops during real session teardown. But that's a workaround: the daemon should be resilient to transient wayland reconfigure events without exiting at all.

**Proper fix (upstream, `build/pkgbuilds/wl/src/wl-main/daemon/`):**

- [ ] Treat `EPIPE` on `wl_display_flush()` as recoverable rather than fatal: tear down the wayland state for the affected output, reconnect the `wl_display`, rebind globals, recreate layer surfaces on the new outputs, rerun `wl restore` internally. No process exit.
- [ ] Wrap the reconnect path behind a bounded retry (e.g. 5 attempts over 10s) so a real session teardown still terminates the daemon eventually rather than looping.
- [ ] Emit a clear log line like `wayland connection lost, reconnecting (attempt N/5)` so journal readers understand what's happening.
- [ ] Keep `Restart=always` in wl.service as defense-in-depth — this change is the *correct* fix, the systemd policy is the *safety net*.

**Secondary cleanup** (same file, cosmetic): the `ExecStartPost=wl restore` retry-loop in the unit file fires before the daemon's IPC socket is ready on fast cold starts, which leaves a `daemon is not running` error line in the journal on every start. Right fix: have `wl-daemon` emit `sd_notify(READY=1)` once the IPC listener is bound, change the unit to `Type=notify`, and drop the sleep-based retry loop entirely. Low priority — the retry loop works, it's just noisy.

**Why not inlined into this session's commits**: unrelated domain. This is upstream work on `github.com/neg-serg/wl` (Rust code), not on the Salt state tree.
