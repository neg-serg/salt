# Quickstart: Salt Refactor Program

## 1. Preconditions

- Current branch: `071-salt-refactor-program`
- Python venv exists (`.venv`)
- Baseline commands available: `just`, `pytest`, Salt local workflow scripts

## 2. Baseline Capture

Run before changes:

```bash
just lint
just validate
just render-matrix
python3 scripts/state-profiler.py --trend > /tmp/state-profiler-baseline.txt
```

## 3. Implement Safe-Now Wave

Apply in this order:

1. Runtime-dir normalization (`openclaw_agent`, `units/user/salt-monitor.service`)
2. Download macro unification (`video_ai`, `_macros_install`, `llama_embed` scope alignment)
3. YAML feature tags for `user_services`
4. Shared runtime bootstrap module (`salt-apply`, `salt-validate`)
5. `Justfile` lint extraction to `scripts/lint-all.sh`
6. Backlog sync in `docs/salt-refactoring-recommendations.md`

Validation after each step:

```bash
just validate
```

## 4. Implement Validation-Gated Wave

1. Add narrow config+restart helper and migrate only truly repeated patterns.
2. Add macro/render contract tests.
3. Add CI performance gate based on profiler compare.
4. Decompose `video_ai.sls`, then `desktop.sls` with explicit includes.

Validation:

```bash
just lint
pytest tests/ -v
just validate
just render-matrix
```

## 5. Performance Regression Check

Capture candidate and compare:

```bash
python3 scripts/state-profiler.py --trend > /tmp/state-profiler-candidate.txt
python3 scripts/state-profiler.py --compare logs/<baseline>.log logs/<candidate>.log --gate --min-sample-count 10
```

## 6. Completion Criteria

- All scoped checks pass locally.
- CI passes including performance gate.
- Refactor backlog document updated with status and risk class.
