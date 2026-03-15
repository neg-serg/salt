# Research: pyinfra Migration Feasibility

**Date**: 2026-03-15
**Feature**: 030-pyinfra-migration-research

## Decision: NO-GO — pyinfra migration is not recommended

**Rationale**: pyinfra's speed advantage is irrelevant for single-host masterless execution. The migration would regress parallel downloads, require 3-5 weeks of rewriting, and trade a mature (if neglected) ecosystem for a single-maintainer project — all for zero measurable speedup on the actual bottleneck (external commands: pacman, curl, makepkg).

**Alternatives considered**:
1. **Full pyinfra migration** — rejected (detailed below)
2. **Hybrid: pyinfra for new states, Salt for existing** — rejected (two CM tools = double maintenance, conflicting state)
3. **Optimize existing Salt** — recommended (more `parallel: True`, better guards, pre-built caches)
4. **Ansible migration** — not evaluated (known to be slower than Salt for single-host)

---

## Research Findings

### 1. Benchmark Analysis

**Official pyinfra benchmarks** (Fizzadar/pyinfra-performance):

| Hosts | pyinfra | Ansible (paramiko) | Ansible (SSH) |
|------:|--------:|-------------------:|--------------:|
| 1     | 1.15s   | 3.15s              | 4.67s         |
| 50    | 4.66s   | 25.14s             | 40.30s        |
| 100   | 8.37s   | 48.99s             | 78.37s        |
| 500   | 49.46s  | 256.98s            | 416.88s       |

**Critical caveat**: These benchmarks measure SSH fan-out to Docker containers with a trivial "ensure file exists" operation. They are **irrelevant for single-host local execution**.

**Salt is not included in any pyinfra benchmark.** No independent third-party benchmarks comparing Salt and pyinfra exist.

**Single-host performance**: Both tools execute via Python subprocess on local machine. pyinfra's `@local` connector uses `subprocess.Popen` — functionally identical to Salt's `cmd.run`. The bottleneck is external commands (pacman ~2-30s per install, curl ~1-10s per download, makepkg ~60-3600s per build), not state compilation.

**State compilation overhead estimate**: Salt's Jinja2+YAML rendering for 36 SLS files takes ~2-5s. pyinfra's Python import is ~0.5-1s. On a total apply of 5-30 minutes, this is <1% — noise.

### 2. Architecture Comparison

| Aspect | Salt (masterless) | pyinfra (`@local`) |
|--------|-------------------|-------------------|
| Execution | `salt-call --local` — Python, no network | `subprocess.Popen` — Python, no network |
| State compilation | Jinja2+YAML → execution graph (~2-5s) | Python import — no rendering (~0.5-1s) |
| Parallel on single host | `parallel: True` per-state | **Not supported** — parallelism is across hosts only |
| Dependency graph | Declarative: `require`, `watch`, `onchanges` | Imperative: top-to-bottom Python order |
| Fact gathering | Grains loaded once at startup (~0.5s) | Facts per-operation, cached per-run |
| Two-phase model | No — states execute as compiled | Yes — prepare all, then execute (facts stale between operations) |
| Dry run | `test=True` | `--dry` (good, leverages two-phase) |

### 3. Feature Gap Matrix (this codebase)

| Salt Feature | Used in codebase | pyinfra Equivalent | Gap Severity |
|---|---|---|---|
| `require` / `require_in` | Extensively (all states) | None — manual Python ordering | **Medium** (achievable but loses graph) |
| `watch:` | 4 occurrences (2 macros, 2 states) | `OperationMeta.did_change` + manual if-blocks | **High** (verbose, error-prone) |
| `onchanges:` | 11 occurrences (6 macros, 5 states) | `OperationMeta.did_change` + manual if-blocks | **High** (verbose, error-prone) |
| `parallel: True` | 4 states (ollama pulls, video_ai, aider, mpv) | **Not possible on single host** | **Critical** (regression, no workaround) |
| `creates:` / `unless:` / `onlyif:` | Every cmd.run state | `_if` callable (lambda/function) | **Medium** (more verbose) |
| `import_yaml` | ~15 data files | `yaml.safe_load()` | **Trivial** |
| Jinja macros (35 macros) | 173 invocations across 41 files | Python functions | **Medium** (rewrite effort, but cleaner) |
| `file.managed` with `source:` | Extensively | `files.put()` + `files.template()` | **Low** |
| `retry:` | All network states via macros | `_retries` + `_retry_delay` | **Trivial** |
| `service.enabled` / `service.running` | Extensively | `systemd.service()` | **Low** |
| `runas:` (user context) | User services, chezmoi | `_su_user` | **Low** |
| `file.serialize` | Occasional | **None** — manual Python | **Medium** |
| State execution scoping | `salt-call state.apply foo` | None — separate deploy files | **Medium** |
| 400+ built-in state modules | 20+ modules used | ~44 operations | **Medium** (fewer built-ins) |

### 4. Parallel Execution Impact

States currently using `parallel: True`:

| State | File | Impact of losing parallelism |
|---|---|---|
| `pull_<model>` (loop) | `ollama.sls` | **High** — pulls 5+ models (2-10 GB each), ~15 min serial vs ~5 min parallel |
| `video_ai_download_<model>` (loop) | `video_ai.sls` | **High** — downloads 10-30 GB model files, ~30 min serial vs ~10 min parallel |
| `aider_install` | `installers.sls` | Low — single pip install |
| `mpv_script_mpris_so` | `installers_mpv.sls` | Low — single file download |

**Estimated regression**: Losing parallelism on ollama + video_ai states would add ~30 minutes to a fresh apply. pyinfra has no mechanism for single-host parallel operations.

### 5. Migration Effort Estimate

| Component | Files | Effort | Risk |
|---|---|---|---|
| Macro library rewrite | 5 files, 35 macros | 2-3 days | Low — Python functions are arguably better |
| Simple states (package installs, file deploys) | ~15 states | 3-5 days | Low |
| Medium states (service management, data-driven) | ~12 states | 5-7 days | Medium — watch/onchanges rewrite |
| Complex states (ollama, video_ai, amnezia, monitoring) | ~9 states | 5-10 days | High — parallel loss, build logic |
| Data files adaptation | ~15 YAML files | 1 day | Low |
| Testing and validation | N/A | 3-5 days | Medium |
| **Total** | | **3-5 weeks** | **Medium-High** |

### 6. Project Health Comparison

| Metric | pyinfra | Salt |
|---|---|---|
| GitHub stars | ~4,900 | ~15,300 |
| Contributors | ~30 | 500+ |
| Bus factor | **1** (Nick Barrett / Fizzadar) | Team (VMware/Broadcom) |
| Built-in operations | ~44 | ~400+ |
| Release cadence | ~6-8 weeks (healthy) | ~quarterly |
| License | MIT | Apache 2.0 |
| Pacman support | `pacman.packages()` | `pkg.installed` with pacman |
| AUR support | None | None (both need macros) |

### 7. pyinfra Two-Phase Model Problem

pyinfra gathers facts during the "prepare" phase and executes all operations in the "execute" phase. Facts are **not re-evaluated between operations**. This means:

```python
# This FAILS in pyinfra:
pacman.packages(packages=["nginx"])  # Install nginx
files.template(src="nginx.conf.j2", dest="/etc/nginx/nginx.conf")  # OK
systemd.service("nginx", running=True)  # May fail — fact about nginx existence is stale
```

Salt does not have this problem — each state executes and subsequent states see updated system state. This is documented as a known limitation (GitHub issue #387).

## Recommendation

**Do not migrate to pyinfra.** The cost-benefit analysis is clearly negative:

| Factor | Value |
|---|---|
| Speed gain on single host | ~0% (bottleneck is external commands) |
| Speed regression from lost parallelism | +30 min on fresh apply |
| Migration effort | 3-5 weeks |
| Regression risk | Medium-High |
| Maintenance risk | Higher (bus factor = 1) |

**Instead, optimize existing Salt**:
1. Add `parallel: True` to more independent download/install states
2. Review idempotency guards for unnecessary re-evaluations
3. Pre-build package caches for frequently-rebuilt PKGBUILDs
4. Profile with `just profile-trend` to find actual bottlenecks
