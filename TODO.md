# TODO

Backlog of ideas and improvements. When ready to implement, run `/speckit.specify` with the description.

---

## Full HD Video Generation (LTX 2.3 22B)

LTX 2.3 22B distilled FP8 works on 7900 XTX (24GB, `--lowvram`). Tested: 512x320, 9 frames, 6 steps → 310s.
Goal: Full HD (1920x1080) at maximum quality.

**gen-video CLI integration:**
- [x] `--lowvram` flag added to `video-ai-generate.sh`
- [x] `__MODEL_FILE__`, `__STEPS__` placeholder substitution added
- [x] `ltx23-distilled-i2v.json` workflow created
- [ ] Update default model to `ltx-23-distilled-fp8`
- [ ] Add 1080p (1920x1080) and 720p (1280x720) resolution presets

**Quality parameters:**
- [ ] Steps: 8 (distilled optimal: 4-8)
- [ ] Test CFG 3.0-5.0 for best quality
- [ ] Width/height must be divisible by 32, frames = 8N+1 (9, 17, 25, 33...)

**Salt state updates:**
- [x] Gemma FP4 + text_projection + tokenizer.model download states added to video_ai.yaml
- [ ] LTX23 VAE download state (repo TBD)
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

## ydotool service not enabled

`ydotool.service` (systemd user unit) is installed but **disabled and inactive**.
Hyprland MCP tools (`mouse_click`, `click_text`, `key_press`, etc.) depend on `ydotoold` running.

**Fix**: Enable the user service in Salt (`user_services.sls` or similar):
```
systemctl --user enable --now ydotool.service
```

Without this, the Hyprland MCP server's mouse/keyboard automation tools fail silently or error on click/type operations. Screenshots still work (they use `grim`/`slurp`, not ydotool).

---

## tg-cli: register own Telegram API credentials

`tg-cli` (pipx, `kabi-tg-cli`) is installed and working with default Telegram Desktop credentials (`api_id=2040`).
This increases the risk of account restrictions from Telegram.

- [ ] Register own app at https://my.telegram.org/apps (requires SMS/Telegram code)
- [ ] Create `~/.config/tg-cli/.env` with `TG_API_ID` and `TG_API_HASH`
- [ ] Re-authenticate: `tg status` (will pick up new credentials)
- [ ] Optionally: store credentials in gopass (`api/telegram-api`)

Note: my.telegram.org form may silently reject — known issue, retry later or from a different browser/IP.

---

## OpenCode Telegram Bots (manual setup)

Salt state `opencode_telegram.sls` is ready. Services are guarded — won't start until tokens are provided.

**Manual steps (Telegram-side):**
- [ ] Create bot via @BotFather for opencode-telegram-bot → `gopass insert api/opencode-telegram-bot`
- [ ] Create bot via @BotFather for telecode → `gopass insert api/telecode-telegram`
- [ ] Run `just apply opencode_telegram` after adding tokens
- [ ] Verify both services start: `systemctl --user status opencode-telegram-bot telecode opencode-serve`

**Optional enhancements:**
- [ ] Add more workspaces to telecode config (currently only `~/src/salt`)
- [ ] Configure STT (voice transcription) for opencode-telegram-bot
- [ ] Add telecode to `salt-monitor` health checks

---

## Verify end-to-end alert pipeline for containerized services (FR-016)

After containerization lands, verify that container failures surface through the existing Loki/Grafana/`monitoring_alerts.sls` stack.

- [ ] Stop a containerized service after cutover and confirm alert fires through the existing channel
- [ ] Record outcome in 087 post-cutover notes

---

## Research / evaluation items

### Nyxt browser packaging

`nyxt-bin` — binary packaging for the Nyxt browser. Needs investigation:
current AUR package may be sufficient, or may need custom PKGBUILD.

### Home LLM cluster — exo / llama.cpp RPC

When building a multi-node home cluster, evaluate distributed LLM inference options:

- **[exo](https://github.com/exo-explore/exo)** (~42k stars) — P2P cluster, auto-discovery via libp2p, auto-sharding across heterogeneous devices. AMD ROCm supported via tinygrad. No AUR package (pip-only). OpenAI-compatible API — plugs into ProxyPilot. Best for: models >VRAM (70B–235B class).
- **llama.cpp RPC backend** — already installed (`llama.cpp-vulkan`). Run `rpc-server` on remote nodes, connect via `--rpc host:50052`. No extra dependencies. Vulkan support. Best for: extending existing stack with minimal overhead.
- **Ollama cluster mode** — in development upstream, may land before cluster is built. Monitor progress.

Decision: prefer llama.cpp RPC (already in stack, AUR package, Vulkan). Revisit exo when AMD ROCm support matures and/or AUR package appears.

### SaluteSpeech — STT/TTS evaluation

Evaluate [SaluteSpeech](https://developers.sber.ru/docs/ru/salutespeech/overview) (Sber) for Russian-language speech recognition (STT) and synthesis (TTS).

- Freemium: ~1000 min/mo STT free tier
- Compare with local alternatives: `faster-whisper` (large-v3), Vosk
- Decision: cloud API (SaluteSpeech) vs self-hosted (Whisper on GPU)
- If adopted: Salt state for setup, API key in gopass, systemd service

---

## Test suite improvements

Audit (2026-04-15): 106 tests across 19 files + 1 shell script. 3 failing, several gaps.

### HIGH PRIORITY

- [ ] **Fix 3 failing tests:**
  - `test_managed_resources_inventory_covers_phase1_services` — remove `adguardhome`, `bitcoind` (now containerized)
  - `test_transmission_uses_shared_config_replace_helper` — update to match consolidated services.sls pattern
  - `test_ci_workflow_wires_performance_gate_status_handling` — `.github/workflows/salt-ci.yaml` doesn't exist
- [ ] **Create `tests/conftest.py`** — shared `REPO_ROOT`, `sys.path` setup, fixtures, pytest markers (`@pytest.mark.slow`, `@pytest.mark.integration`)
- [ ] **Move `cmd.run` audit from report-only to failing** — currently 70/499 unguarded states silently pass CI. Add threshold-based fail.
- [ ] **Add `@pytest.mark.slow` to module-level render tests** — `test_macro_idempotency.py` and `test_cmdrun_audit.py` render ALL .sls at import time

### MEDIUM PRIORITY

- [ ] **Add service catalog consistency tests** — verify `service_catalog.yaml` entries have valid units, templates exist, packages resolve
- [ ] **Add macro output tests** — test `_macros_service.jinja` helpers produce expected state structures with specific arguments
- [ ] **Add tests for critical scripts:** `update-tools.py`, `salt-daemon.py`, `lint-jinja.py`
- [ ] **Add containerized services tests** — verify Quadlet files exist for declared containers, bind-mounts match state paths
- [ ] **Deduplicate REPO_ROOT** — remove ~15 copies of `REPO_ROOT = Path(__file__).resolve().parent.parent` after conftest.py exists

### LOWER PRIORITY

- [ ] Add tests for nanoclaw.sls and ollama.sls (key user-facing services)
- [ ] Add YAML schema validation for packages.yaml, versions.yaml, hosts.yaml
- [ ] Add idempotency test — render states twice, compare output

---

## wl-daemon: reconnect-on-broken-pipe instead of graceful shutdown

> **Upstream work** (`github.com/neg-serg/wl`, Rust code) — not a Salt repo task.
> Kept here as a tracking note.

When the Wayland compositor emits a fast output-remove-and-readd sequence (monitor hotplug, mode change, `hyprctl reload`, DPMS cycle), `wl-daemon` can race a pending `wl_display_flush()` against the now-closed `wl_output`. The flush returns `EPIPE` (Broken pipe), the error propagates as `wayland flush error` to the main loop, and the daemon currently chooses to `shutting down` cleanly (exit status 0).

**Proper fix (upstream):**
- [ ] Treat `EPIPE` on `wl_display_flush()` as recoverable rather than fatal
- [ ] Wrap reconnect behind bounded retry (5 attempts over 10s)
- [ ] Emit clear log line: `wayland connection lost, reconnecting (attempt N/5)`
- [ ] Keep `Restart=always` in wl.service as defense-in-depth

**Secondary cleanup** (cosmetic): `ExecStartPost=wl restore` retry-loop in the unit file fires before daemon's IPC socket is ready. Fix: `sd_notify(READY=1)` + `Type=notify` + drop sleep-based retry loop.
