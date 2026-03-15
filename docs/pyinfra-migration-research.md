# pyinfra Migration Research: Salt vs pyinfra for Single-Host Workstation

**Date**: 2026-03-15
**Recommendation**: **DO NOT MIGRATE** — pyinfra offers no meaningful speed gain for single-host masterless execution and introduces critical regressions.

## Executive Summary

| Factor | Value |
|--------|-------|
| Speed gain (fresh apply) | **~0%** — bottleneck is external commands (pacman, curl, makepkg) |
| Speed gain (idempotent apply) | **~5-6s** faster (12s → 6-7s) — startup overhead only |
| Speed regression (lost parallelism) | **+30 min** on fresh apply (ollama + video_ai model downloads) |
| Migration effort | **3-5 weeks** (35 macros, 41 state files, 173 macro invocations) |
| Regression risk | **Medium-High** — watch/onchanges patterns, two-phase fact staleness |
| pyinfra bus factor | **1** developer (Nick Barrett) vs Salt's 500+ contributors |
| Net benefit | **Negative** — costs exceed benefits by wide margin |

---

## 1. Speed Comparison

### 1.1 Benchmark Methodology

Measurements taken from Salt's own profiling system (`scripts/state-profiler.py --trend`) across 126 apply logs on CachyOS workstation. pyinfra estimates are theoretical (both tools execute identical external commands via subprocess).

### 1.2 Idempotent (No-Change) Apply

| Phase | Salt | pyinfra (estimated) | Difference |
|-------|------|---------------------|------------|
| Startup (module/grain loading) | 5-6s | 1-2s | -4s |
| State compilation (Jinja+YAML) | 2-3s | 0s (Python imports) | -2s |
| State execution (566 idempotent checks) | 4.3s | ~4-5s | ~0s |
| **Total** | **~12s** | **~6-7s** | **~5-6s faster** |

pyinfra saves ~5-6s on idempotent applies by eliminating Jinja2 rendering and Salt's module loading system. However, this saving is:
- **Irrelevant for fresh applies** (5-30 minutes) — external commands dominate
- **Only noticeable when nothing changes** — which means the system is already correctly configured

### 1.3 Fresh Apply with Downloads

| Workload | Time | Bottleneck |
|----------|------|------------|
| Package installs (pacman -S) | 2-30s per package | pacman lock, network |
| Binary downloads (curl) | 1-10s per file | Network bandwidth |
| PKGBUILD builds (makepkg) | 60-3600s per build | CPU, compilation |
| Model pulls (ollama pull) | 60-600s per model | Network, disk I/O |
| Total fresh apply | 5-30 minutes | External commands |

Both tools execute these via `subprocess.Popen` (Salt's `cmd.run` ≈ pyinfra's `server.shell()`). The tool overhead is <1% of total time. **There is no speed advantage to capture.**

### 1.4 Parallel Execution Regression

Salt supports `parallel: True` for independent states on a single host. pyinfra does **not** — its parallelism is across hosts only.

| Parallel State | File | Serial Time | Parallel Time | Regression |
|---------------|------|-------------|---------------|------------|
| `pull_<model>` (5+ models) | ollama.sls | ~15 min | ~5 min | **+10 min** |
| `video_ai_download_<model>` | video_ai.sls | ~30 min | ~10 min | **+20 min** |
| `aider_install` | installers.sls | ~30s | ~30s | negligible |
| `mpv_script_mpris_so` | installers_mpv.sls | ~2s | ~2s | negligible |
| **Total regression** | | | | **+30 min** |

This is the single most damaging impact of migration. There is no workaround in pyinfra — you would need to implement custom `asyncio`/`threading` wrappers outside pyinfra's operation model.

### 1.5 Speed Verdict

| Scenario | Salt | pyinfra | Winner |
|----------|------|---------|--------|
| Idempotent apply | 12s | ~6-7s | pyinfra (+5s) |
| Fresh apply (no parallel states) | 5-10 min | 5-10 min | Tie |
| Fresh apply (with model downloads) | 15-20 min | 45-50 min | **Salt (+30 min)** |

---

## 2. Feature Gap Matrix

### 2.1 Summary

| Gap Severity | Count | Impact |
|-------------|-------|--------|
| Critical | 1 | `parallel: True` — no workaround |
| High | 2 | `watch:`/`onchanges:` — verbose replacement |
| Medium | 6 | Dependency graph, guards, scoping, built-ins |
| Low/Trivial | 5 | File management, retry, data loading |

### 2.2 Detailed Mapping

| Salt Feature | Used | pyinfra Equivalent | Gap |
|---|---|---|---|
| `parallel: True` | 4 states | **None** (single-host) | **Critical** |
| `watch:` | 4 directives | `OperationMeta.did_change` | **High** — verbose |
| `onchanges:` | 11 directives | `OperationMeta.did_change` | **High** — verbose |
| `require` / `require_in` | All states | Manual Python ordering | Medium |
| `creates:` / `unless:` / `onlyif:` | Every cmd.run | `_if` callable | Medium |
| State execution scoping | `salt-call state.apply foo` | Separate deploy files | Medium |
| `file.serialize` | Occasional | Manual Python | Medium |
| 400+ state modules | 20+ used | ~44 operations | Medium |
| `import_yaml` | ~15 data files | `yaml.safe_load()` | Trivial |
| `retry:` | All network states | `_retries` + `_retry_delay` | Trivial |
| Jinja macros (35) | 173 invocations | Python functions | Medium (effort) |
| `file.managed` with `source:` | Extensively | `files.template()` | Low |
| `service.enabled`/`running` | Extensively | `systemd.service()` | Low |
| `runas:` | User services | `_su_user` | Low |

### 2.3 watch/onchanges Migration Pattern

Salt's declarative `onchanges:` (3 lines of YAML):
```yaml
udev_reload:
  cmd.run:
    - name: udevadm control --reload-rules
    - onchanges:
      - file: udev_rule_file
```

pyinfra equivalent (~8 lines of Python):
```python
rule_op = files.put(
    name="udev_rule_file",
    src="50-qmk.rules",
    dest="/etc/udev/rules.d/50-qmk.rules",
)
with rule_op.did_change:
    server.shell(
        name="udev_reload",
        commands=["udevadm control --reload-rules"],
    )
```

This pattern must be applied to all 15 watch/onchanges directives. The pyinfra version is ~2.5x more verbose and requires restructuring macro return values to expose `OperationMeta` objects.

### 2.4 Two-Phase Model Limitation

pyinfra gathers facts during "prepare" phase and does not re-evaluate between operations. This breaks common install→configure→start patterns:

```python
# FAILS: fact about nginx is stale from prepare phase
pacman.packages(packages=["nginx"])
files.template(src="nginx.conf.j2", dest="/etc/nginx/nginx.conf")
systemd.service("nginx", running=True)  # May fail — nginx not "known" yet
```

Salt does not have this problem — each state sees the system state left by previous states. Workaround in pyinfra: split deploys into multiple files or use `_if` guards instead of fact-based operations.

---

## 3. Migration Effort Estimate

### 3.1 Proof-of-Concept Port

`installers.sls` was ported to pyinfra as a representative data-driven state file.

| Metric | Salt | pyinfra |
|--------|------|---------|
| Lines of code | 112 (+ ~200 shared macros) | ~220 (self-contained) |
| Macro definitions | 6 macros in shared files | 6 functions inline |
| Data loading | `import_yaml` (1 line) | `yaml.safe_load()` (3 lines) |
| Idempotency guards | `creates:` (1 line per state) | `_if=lambda: ...` (1 line, more verbose) |
| Parallel downloads | `parallel: True` on all downloads | Not possible |
| Change tracking | `onchanges:` for udev reload | Unconditional reload (no clean equivalent) |
| Porting time | — | ~2 hours |

### 3.2 Full Codebase Estimate

| Complexity | Files | Hours Each | Total Hours | Risk |
|-----------|-------|------------|-------------|------|
| **Hard** | 9 (ollama, video_ai, amnezia, monitoring, dns, services, desktop, fonts, custom_pkgs) | 8-24h | 72-216h | High — parallel loss, build logic, heavy macro usage |
| **Medium** | 12 (user_services, kanata, mpd, floorp, installers_desktop, openclaw, opencode, greetd, steam, network, tidal, installers_themes) | 4-8h | 48-96h | Medium — watch/onchanges rewrite |
| **Trivial** | 15 (packages, users, zsh, audio, mounts, sysctl, kernel_*, bind_mounts, snapshots, cachyos*, hardware, llama_embed, system_description) | 1-2h | 15-30h | Low — simple package/file/service |
| **Macro library** | 5 files (35 macros) | — | 16-24h | Low — cleaner as Python |
| **Testing** | — | — | 24-40h | Medium |
| **Total** | **41 files** | | **175-406h (3-5 weeks)** | **Medium-High** |

### 3.3 Risk Factors

1. **Parallel execution loss**: No mitigation path in pyinfra. Would need custom threading wrapper.
2. **Two-phase fact staleness**: install→configure→start patterns need restructuring.
3. **watch/onchanges rewrite**: 15 directives, each becomes more verbose and error-prone.
4. **Reduced built-in operations**: pyinfra has ~44 vs Salt's ~400+ modules.
5. **Single maintainer risk**: pyinfra bus factor = 1 (see Section 4).

---

## 4. Project Health Comparison

| Metric | pyinfra | Salt |
|--------|---------|------|
| GitHub stars | ~4,900 | ~15,300 |
| Forks | ~467 | ~5,572 |
| Contributors | ~30 | 500+ |
| Bus factor | **1** (Nick Barrett) | Team (VMware/Broadcom) |
| Built-in modules | ~44 | ~400+ |
| Release cadence | ~6-8 weeks | ~quarterly |
| License | MIT | Apache 2.0 |
| Pacman support | `pacman.packages()` | `pkg.installed` |
| AUR support | None | None (both need macros) |
| Documentation | Good basics, thin advanced | Extensive but sprawling |

**Risk assessment**: pyinfra is a healthy project with regular releases, but its single-maintainer nature is a long-term risk. If Nick Barrett stops maintaining it, there's no organizational backing. Salt, despite Broadcom's post-acquisition neglect, has deep enterprise adoption and a large contributor base that provides more resilience.

---

## 5. Recommendation

### 5.1 Decision: NO-GO

The cost-benefit analysis is clearly negative:

| Criteria | Threshold | Result | Pass? |
|----------|-----------|--------|-------|
| Speed gain (fresh apply) | >20% improvement | ~0% | **FAIL** |
| Speed regression | <5% regression | +30 min (+100-200%) | **FAIL** |
| Migration effort | <2 weeks | 3-5 weeks | **FAIL** |
| Ecosystem risk | Comparable or better | Worse (bus factor 1) | **FAIL** |
| Feature parity | No critical gaps | 1 critical, 2 high gaps | **FAIL** |

### 5.2 Recommended Alternative: Optimize Existing Salt

Instead of migrating, improve Salt performance directly:

1. **Audit for more `parallel: True` opportunities** — many independent install states could run concurrently
2. **Profile with `just profile-trend`** — identify actual slow states (top candidates: video_ai_comfyui_setup avg 54s, install_opensoundmeter avg 3.3s)
3. **Pre-built package caches** — avoid rebuilding PKGBUILDs that haven't changed
4. **Better idempotency guards** — reduce unnecessary `unless:` shell-outs with faster checks (e.g., version file markers)
5. **Salt module loading optimization** — disable unused Salt modules in minion config to reduce startup time

### 5.3 When pyinfra Would Be the Right Choice

pyinfra excels in scenarios that don't apply here:
- **Multi-host deployment** (50+ servers over SSH) — pyinfra is 5-8x faster than Ansible
- **Python-native tooling** — when you want standard Python linting, testing, type checking on your CM code
- **Embedding CM in larger Python applications** — pyinfra's API is cleaner for programmatic use
- **Greenfield projects** without existing Salt investment

---

## Appendix A: Official pyinfra Benchmarks

Source: [Fizzadar/pyinfra-performance](https://github.com/Fizzadar/pyinfra-performance)

| Hosts | pyinfra | Ansible (paramiko) | Ansible (SSH) |
|------:|--------:|-------------------:|--------------:|
| 1 | 1.15s | 3.15s | 4.67s |
| 50 | 4.66s | 25.14s | 40.30s |
| 100 | 8.37s | 48.99s | 78.37s |
| 500 | 49.46s | 256.98s | 416.88s |

**Critical caveat**: These benchmarks measure SSH fan-out with a trivial "ensure file exists" operation. They are irrelevant for single-host local execution. Salt is not included in any pyinfra benchmark.

## Appendix B: Salt Baseline Profile

From `just profile-trend` across 126 apply logs:

- **Total states per apply**: 566
- **Idempotent apply time**: 4.3s (state execution) / ~12s (wall-clock)
- **Slowest states** (avg ms): video_ai_comfyui_setup (54,491), install_opensoundmeter (3,324), video_ai nodes (404-1,443), build_tailray (658)
- **Service checks** (avg ms): telethon_bridge_enabled (279), mpd_enabled (270), enable_user_services (158)
- **Most states**: Complete in <20ms on idempotent apply
