# Design: lint-jinja.py — cross-file validation

## Goal

Extend `scripts/lint-jinja.py` with three new checks:
1. **require-resolve** — all `require:`/`watch:`/`onchanges:` references point to existing state IDs
2. **unused-imports** — imported macros are actually used in the file
3. **dangling-includes** — files in the `include:` list (system_description.sls) exist on disk

## Current linter architecture

File: `scripts/lint-jinja.py`. Checks:
- `check_jinja_syntax()` — renders all .jinja/.sls via Jinja2 with mock context
- `check_duplicate_state_ids()` — renders .sls, parses YAML, finds duplicate IDs
- `check_state_id_naming()` — regex on raw .sls files, validates conventions
- `check_host_config()` — validates keys in host_config.jinja
- `check_yaml_configs()` — yaml.safe_load on data/*.yaml

Rendering uses `jinja2.Environment` with `SaltTagExtension` (handles `{% import_yaml %}`, `{% do %}`) and a stub context `grains={"host": "lint-check"}`. Not all files render — files with Salt-only features (pillar, etc.) are silently skipped.

## Pitfalls (CRITICAL)

### 1. Macros generate state IDs by pattern

Macros from `_macros_*.jinja` create state IDs with predictable prefixes:

| Macro | Generated IDs |
|---|---|
| `pacman_install(name, ...)` | `install_{name}` |
| `paru_install(name, ...)` | `install_{name}` |
| `pkgbuild_install(name, ...)` | `{name}_pkgbuild`, `build_{name}` |
| `simple_service(name, ...)` | `install_{name}`, `{name}_enabled` |
| `service_with_unit(name, ...)` | `{name}_service`, `{name}_daemon_reload`, `{name}_enabled`/`{name}_disabled`, `{name}_reset_failed`, `{name}_running` |
| `ensure_running(name, ...)` | `{name}_reset_failed`, `{name}_running` |
| `system_daemon_user(name, ...)` | `{name}_user`, `{name}_data_dir` |
| `unit_override(name, ...)` | `{name}`, `{name}_reload` |
| `ensure_dir(name, ...)` | `{name}` |
| `udev_rule(name, ...)` | `{name}`, `{name}_reload` |
| `service_stopped(name, ...)` | `{name}` |
| `curl_bin(name, ...)` | `install_{name}` |
| `curl_extract_tar(name, ...)` | `install_{name}` |
| `curl_extract_zip(name, ...)` | `install_{name}` |
| `github_tar(name, ...)` | `install_{name}` |
| `github_release_system(name, ...)` | `install_{name}` |
| `pip_pkg(name, ...)` | `install_{name}` |
| `cargo_pkg(name, ...)` | `install_{name}` |
| `npm_pkg(name, ...)` | `install_{name}` |
| `firefox_extension(ext, ...)` | `floorp_ext_{slug}` |
| `user_service_file(name, ...)` | `{name}` |
| `user_service_enable(name, ...)` | `{name}` |
| `user_unit_override(name, ...)` | `{name}`, `{name}_daemon_reload` |
| `service_with_healthcheck(name, ...)` | `{name}` |
| `download_font_zip(name, ...)` | `install_{name}` |
| `git_clone_deploy(name, ...)` | `install_{name}`, `install_{name}_deploy` |

All `name` values pass through `| replace('-', '_')` during ID generation.

The linter must know these patterns so that when it encounters `require: cmd: install_unbound`, it understands this is a valid reference to `pacman_install('unbound', ...)` or `simple_service('unbound', ...)`.

### 2. Conditional state IDs

Many states are wrapped in `{% if host.features.dns.unbound %}...{% endif %}`. During lint-time rendering with mock grains, feature flags may be False, and states won't be generated. Solutions:
- **Approach A**: Render with an "all-features-on" mock context (requires knowing the features structure)
- **Approach B**: Parse require references from raw text (regex), not from rendered YAML
- **Approach C**: Render multiple times with different host configs from `host_config.jinja`

Recommendation: **approach B** for require-resolve (regex on raw files), **approach A** for completeness (as an additional mode). The existing `check_duplicate_state_ids()` function uses rendering — its result (`all_ids`) can be extended but should not be the sole source.

### 3. Cross-file dependencies

`dns.sls` can reference state IDs from `system_description.sls` (via `include:`). Example: `require: cmd: pacman_db_warmup` is defined in `desktop.sls` but used across all files via macros.

Solution: build a **global state ID pool** from all .sls files rather than checking each file in isolation.

### 4. Sanitization during ID generation

State IDs pass through `| replace('-', '_')`, and sometimes through more complex chains:
```
model | replace('.', '_') | replace(':', '_') | replace('-', '_')
ext_id | replace('{', '') | replace('}', '') | replace('-', '_') | replace('@', '_') | replace('.', '_')
```
Require references use the already-sanitized form. The linter should either parse replace chains or simply check IDs as-is (after rendering).

### 5. YAML data affects state IDs

Data-driven loops (`{% for name, opts in tools.curl_bin.items() %}`) generate IDs based on `data/*.yaml` contents. The linter already loads these files via `_resolve_import_yaml()` — this must be preserved.

### 6. `require` format — not just `cmd:`

Requisite format: `- {type}: {state_id}`, where type = `cmd`, `file`, `service`, `user`, `mount`, `pkg`. The linter must parse all types.

### 7. Macro calls inside Jinja — not visible in YAML

`{{ pacman_install('foo', 'foo') }}` in a raw file is a Jinja expression, not YAML. For the unused-imports check, macro names must be searched in raw file text (regex), not in rendered YAML.

### 8. False positives

Some require references are valid but not verifiable:
- `require: mount: mount_zero` — from `mounts.sls`, may not render
- `require: cmd: pacman_db_warmup` — from `desktop.sls`, global dependency
- References inside macros (e.g. `require: cmd: pacman_db_warmup` in `_macros_pkg.jinja`)

A **known-globals** mechanism is needed — a list of state IDs that are always considered available.

## Recommended implementation plan

### Phase 1: unused-imports (simple, regex-based)
- For each .sls: parse `{% from '...' import foo, bar %}`
- For each imported name: check if `foo(` or `foo ` appears in the file body
- Exclude `_macros_common.jinja` imports (they are re-imported inside macros)
- Severity: warning (not error)

### Phase 2: require-resolve (medium complexity)
- Build a global state ID pool from all rendered .sls (extend `check_duplicate_state_ids`)
- Add known-globals: `pacman_db_warmup`, `mount_zero`, `mount_one`
- For each rendered .sls: find all `require:`/`watch:`/`onchanges:` blocks
- For each reference `- {type}: {id}`: verify `{id}` exists in the global pool or known-globals
- Severity: error

### Phase 3: dangling-includes (trivial)
- Read `system_description.sls`, find the `include:` list
- For each name: verify `states/{name}.sls` exists
- Severity: error

## Key files

- `scripts/lint-jinja.py` — main file to modify
- `states/_macros_*.jinja` — reference for generated state IDs (read, don't modify)
- `states/_imports.jinja` — defines retry_attempts, etc.
- `states/host_config.jinja` — feature flags for mock context
- `states/data/*.yaml` — data affecting state IDs
- `states/system_description.sls` — include list

## Acceptance criteria

- `python3 scripts/lint-jinja.py` passes on the current codebase with 0 errors
- A deliberately broken require (e.g. `require: cmd: nonexistent_state`) is detected
- An unused import is detected as a warning
- A non-existent include is detected as an error
- False positive rate = 0 on the current codebase (if a suppress mechanism is needed — inline `# lint: ignore`)
