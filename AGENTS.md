# salt Development Guidelines

Auto-generated from active feature plans. Last updated: 2026-03-24

## Active Technologies
- Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts
- Salt 3006.x masterless workflow with shared `_macros_*.jinja`
- `just`, `pytest`, `ruff`, `shellcheck`, `yamllint`, `salt-lint`, GitHub Actions
- Repository artifacts under `states/`, `scripts/`, `tests/`, `docs/`, `.github/workflows/`
- Markdown documentation, shell-based operator workflow, existing `gopass` CLI usage in Salt/chezmoi scripts + `gopass` 1.16.x, current git-backed password store, `chezmoi`, Salt masterless workflow, existing docs under `docs/` (072-gopass-age-migration)
- File-based `gopass` store plus git history and local backup artifacts (072-gopass-age-migration)

## Project Structure

```text
states/
scripts/
tests/
docs/
.github/workflows/
specs/
```

## Commands

- `just lint`
- `pytest tests/ -q`
- `just validate`
- `just render-matrix`
- `python3 scripts/state-profiler.py --trend`
- `python3 scripts/state-profiler.py --compare <baseline> <candidate> --gate --min-sample-count 10`

## Code Style

- Prefer explicit Salt/Jinja structure over meta-generated topology.
- Keep macros narrow and operationally transparent.
- Preserve state ID readability and uniqueness across includes.
- Treat `states/**/*.sls` as the supported state tree for lint/render/index tooling.

## Recent Changes
- 072-gopass-age-migration: Added Markdown documentation, shell-based operator workflow, existing `gopass` CLI usage in Salt/chezmoi scripts + `gopass` 1.16.x, current git-backed password store, `chezmoi`, Salt masterless workflow, existing docs under `docs/`

- `071-salt-refactor-program`: normalized runtime-dir handling, unified Hugging Face downloads, moved user-service feature tags into YAML, extracted shared Salt runtime bootstrap and lint script, added service/perf guardrails, and decomposed `video_ai` / `desktop` into explicit include trees.
- `048-salt`: established the baseline Salt/Jinja + helper-script workflow and profiling/index tooling.

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
