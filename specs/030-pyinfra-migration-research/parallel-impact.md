# Parallel Execution Impact Analysis

pyinfra v3.7 has **no single-host parallel execution**. All operations run sequentially on a given host. Salt's `parallel: True` allows independent states to execute concurrently within a single minion apply.

This document analyzes the 4 states that explicitly use `parallel: True` and estimates the time regression from forced serialization.

---

## State 1: ollama.sls -- Model Pulls

**What it does**: Pulls 15 LLM models from the Ollama registry via `ollama pull`. Each model download is independent -- they require only that the Ollama server is running (shared `ollama_start` prerequisite).

**Models and estimated sizes** (from `data/ollama.yaml`):

| Model | Est. Size | Est. Download Time (100 Mbps) |
|-------|-----------|-------------------------------|
| gemma3:12b | ~7 GB | 9 min |
| qwen3:14b | ~9 GB | 12 min |
| qwen3.5:27b | ~17 GB | 23 min |
| qwen2.5-coder:7b | ~4 GB | 5 min |
| qwen3-coder:30b | ~19 GB | 25 min |
| deepcoder:14b | ~9 GB | 12 min |
| deepseek-coder-v2:16b | ~9 GB | 12 min |
| codestral:22b | ~13 GB | 17 min |
| starcoder2:15b | ~9 GB | 12 min |
| qwen2.5vl:7b | ~5 GB | 7 min |
| qwen3:235b-a22b | ~142 GB | 189 min |
| qwen3:32b | ~20 GB | 27 min |
| llama3.1:70b | ~43 GB | 57 min |
| mistral-nemo | ~7.5 GB | 10 min |
| gemma3:27b | ~17 GB | 23 min |

**Salt behavior (parallel: True)**: All 15 `ollama pull` commands run concurrently. Ollama's server handles concurrent pull requests, and bandwidth is the bottleneck. With 100 Mbps effective throughput, parallel time is dominated by the largest model.

- **Parallel time**: ~189 min (limited by qwen3:235b-a22b at 142 GB; smaller models download concurrently within remaining bandwidth)
- **Realistic parallel time**: ~210 min (accounting for bandwidth contention, ~15 concurrent streams saturating the pipe)
- **Serial time**: Sum of all models = ~440 min (~7.3 hours)
- **Regression**: ~230 min (+110%)
- **Timeout**: Each pull has `timeout: 14400` (4 hours). Serial execution of 15 models in 7.3 hours is within the per-model timeout, but the total apply time is unacceptable.

**Mitigation in pyinfra**: None built-in. Workaround: use Python `subprocess` with `threading` or `asyncio` to spawn parallel `ollama pull` processes, but this breaks pyinfra's operation model (no `OperationMeta` tracking).

---

## State 2: video_ai.sls -- Model Downloads

**What it does**: Downloads large AI model files from HuggingFace via `curl -fsSL -C -`. Each model has 1-2 files, with independent downloads per file. All downloads require their model directory to exist first.

**Models and estimated sizes** (from `data/video_ai.yaml`, when enabled):

| Model | Files | Est. Size | Est. Download Time (100 Mbps) |
|-------|-------|-----------|-------------------------------|
| ltx-video-2b | 1 | ~4 GB | 5 min |
| hunyuanvideo-15 | 1 | ~8 GB | 11 min |
| wan21-t2v-14b | 1 | ~10 GB | 13 min |
| wan21-t2v-1.3b | 1 | ~2.5 GB | 3 min |
| cogvideox-5b | 2 | ~20 GB | 27 min |
| wan21-i2v-14b | 1 | ~10 GB | 13 min |

**Note**: All models are currently `enabled: false` in the YAML. When enabled, typically 2-3 models are active simultaneously.

**Assuming 3 models enabled (ltx-video-2b, hunyuanvideo-15, wan21-t2v-14b)**:

- **Parallel time**: ~13 min (limited by largest single file: wan21-t2v-14b at 10 GB)
- **Serial time**: 5 + 11 + 13 = ~29 min
- **Regression**: ~16 min (+123%)

**Assuming all 6 models enabled (7 files total)**:

- **Parallel time**: ~27 min (limited by cogvideox-5b part 1 at 10 GB, with bandwidth contention)
- **Serial time**: 5 + 11 + 13 + 3 + 27 + 13 = ~72 min
- **Regression**: ~45 min (+167%)

**Mitigation**: Same as ollama -- no pyinfra-native solution. The `curl -C -` (resume) flag means interrupted downloads can be retried without starting over, but this doesn't help with parallelism.

---

## State 3: installers.sls -- aider pip install

**What it does**: Single `uv tool install aider-chat --python 3.12` command. Marked `parallel: True` because it runs alongside other install macros in the same state file (which also have `parallel: True` from their macros).

**Timing**:
- **Install time**: ~30-60 seconds (pip download + install of aider-chat and dependencies)
- **No parallelism benefit in isolation**: This is a single command. The `parallel: True` allows it to run concurrently with other installer states in the same file.

**Context**: `installers.sls` includes ~20 other install macros (curl_bin, pip_pkg, cargo_pkg, etc.), all of which have `parallel: True` from their macro definitions. The total parallel window is significant.

**Estimated parallel impact for all of installers.sls** (not just aider):

| Category | Count | Avg Time | Serial Total |
|----------|-------|----------|-------------|
| curl_bin | ~12 | 5s | 60s |
| pip_pkg | ~4 | 30s | 120s |
| cargo_pkg | ~8 | 60s | 480s |
| curl_extract_tar | ~6 | 10s | 60s |
| curl_extract_zip | ~4 | 10s | 40s |
| git_clone_deploy | ~2 | 15s | 30s |
| Other | ~5 | 15s | 75s |
| **Total** | **~41** | | **~865s (~14 min)** |

- **Parallel time** (Salt): ~120s (~2 min, limited by slowest cargo build)
- **Serial time** (pyinfra): ~865s (~14 min)
- **Regression for all installers**: ~12 min (+600%)

**Note**: The aider-specific regression is negligible (~30s overlap with other installs), but the aggregate impact of losing `parallel: True` across all install macros is severe.

---

## State 4: installers_mpv.sls -- mpris.so download

**What it does**: Single GitHub release download of `mpris.so` (mpv MPRIS plugin, ~200 KB). Marked `parallel: True` from the macro.

**Timing**:
- **Download time**: ~2-3 seconds
- **Serial overhead**: negligible (2-3 seconds)
- **Regression**: ~0 seconds (effectively zero)

**Context**: This state runs alongside other mpv plugin installs in `installers_mpv.sls`, but those are also small downloads. Total serial time for all mpv installers is under 30 seconds.

---

## Summary Table

| State | Parallel Time | Serial Time | Regression | % Slower |
|-------|--------------|-------------|------------|----------|
| ollama.sls (15 models) | ~210 min | ~440 min | +230 min | +110% |
| video_ai.sls (3 models) | ~13 min | ~29 min | +16 min | +123% |
| video_ai.sls (6 models) | ~27 min | ~72 min | +45 min | +167% |
| installers.sls (all macros) | ~2 min | ~14 min | +12 min | +600% |
| installers_mpv.sls | ~3s | ~3s | ~0s | ~0% |
| **Total (typical run)** | **~225 min** | **~483 min** | **+258 min** | **+115%** |

### Worst-Case Total Regression

A full apply with all models enabled:

- **Salt parallel**: ~237 min (~4 hours)
- **pyinfra serial**: ~526 min (~8.8 hours)
- **Regression**: ~289 min (+122%)

### Impact Assessment

1. **Ollama model pulls are the critical path**. The 15 models total ~330 GB. Serialized downloads nearly double the total apply time. On a fresh install, this alone takes 7+ hours serially.

2. **Installer macros suffer the highest percentage regression** (+600%) but the absolute time is manageable (~12 min increase). This is because individual install operations are fast (seconds), but there are ~41 of them.

3. **Video AI models are gated by `enabled: false`** in most configurations. When 2-3 models are enabled, the ~16 min regression is tolerable.

4. **mpris.so is negligible** -- the `parallel: True` is inherited from the macro and provides no meaningful benefit.

### Workarounds

| Approach | Complexity | Coverage | Drawbacks |
|----------|-----------|----------|-----------|
| Python threading wrapper | High | Full | Breaks pyinfra operation model, no `OperationMeta` |
| Split into multiple pyinfra deploys | Medium | Partial | Complex orchestration, multiple processes |
| GNU `parallel` in shell | Low | Model pulls only | Loses per-model error tracking, crude |
| Pre-download script (outside pyinfra) | Low | Full | Two-step workflow, state outside pyinfra |
| Accept regression | None | N/A | 4h -> 8.8h on fresh install is painful |

**Recommendation**: For this codebase (masterless, single-host), the loss of `parallel: True` is the single largest practical regression from a pyinfra migration. The ollama model pulls alone make a full fresh-install apply unacceptably slow. Any migration must address this, likely via a custom parallel execution wrapper outside pyinfra's operation model.
