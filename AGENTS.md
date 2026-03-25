# salt Development Guidelines

Auto-generated from active feature plans. Last updated: 2026-03-26

## Active Technologies
- Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts
- Salt 3006.x masterless workflow with shared `_macros_*.jinja`
- `just`, `pytest`, `ruff`, `shellcheck`, `yamllint`, `salt-lint`, GitHub Actions
- Repository artifacts under `states/`, `scripts/`, `tests/`, `docs/`, `.github/workflows/`
- Markdown documentation, shell-based operator workflow, existing `gopass` CLI usage in Salt/chezmoi scripts + `gopass` 1.16.x, current git-backed password store, `chezmoi`, Salt masterless workflow, existing docs under `docs/` (072-gopass-age-migration)
- File-based `gopass` store plus git history and local backup artifacts (072-gopass-age-migration)
- Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts + Salt 3006.x masterless workflow, existing `_macros_*.jinja`, systemd, Arch/CachyOS package management, `zapret2` AUR package (`0.9.4.5-1` observed during planning) (073-zapret2-dry-run)
- Repository-managed config templates and data files plus local file-based readiness/rollback metadata on the target machine (073-zapret2-dry-run)
- Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts + Salt 3006.x masterless workflow, existing `_macros_*.jinja`, systemd, Arch/CachyOS package management, repository-managed unit/config trees (074-sysusers-tmpfiles-adoption)
- Repository-managed Salt states, config templates, unit files, and generated `sysusers.d` / `tmpfiles.d` policy fragments on the target machine (074-sysusers-tmpfiles-adoption)
- Markdown, YAML, Bash/Zsh operator workflows, `gopass` 1.16.x + `gopass`, `age`, existing git-backed password store, chezmoi, Salt masterless workflow, spec-kit artifacts (072-gopass-age-migration)
- File-based `gopass` store plus git history and offline rollback artifacts (072-gopass-age-migration)

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
- 075-gopass-age-cutover: Added Markdown, YAML, Bash/Zsh operator workflows, `gopass` 1.16.x + `gopass`, `age`, existing git-backed password store, chezmoi, Salt masterless workflow, spec-kit artifacts
- 072-gopass-age-migration: Added Markdown, YAML, Bash/Zsh operator workflows, `gopass` 1.16.x + `gopass`, `age`, existing git-backed password store, chezmoi, Salt masterless workflow, spec-kit artifacts
- 074-sysusers-tmpfiles-adoption: Added Jinja2 + YAML Salt states, Python 3, Bash/Zsh helper scripts + Salt 3006.x masterless workflow, existing `_macros_*.jinja`, systemd, Arch/CachyOS package management, repository-managed unit/config trees


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
