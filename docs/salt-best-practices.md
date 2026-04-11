# Salt Best Practices & LLM Integration Guide (2023-2026)

This document is a comprehensive reference for Salt configuration management best practices, with a focus on masterless single-workstation setups and LLM-assisted development. Each practice includes an audit status for this project.

**Scope**: Salt Project 3006-3008, masterless mode, CachyOS (Arch-based)
**Audience**: Developers maintaining this Salt codebase + AI tools (Claude Code, OpenCode)
**Relationship to CLAUDE.md**: CLAUDE.md encodes *rules for AI to follow* (prescriptive, terse). This document explains *why those rules exist* and covers broader topics (ecosystem health, alternatives, testing strategy). Cross-references CLAUDE.md by section — does not duplicate it.

**Status markers**: ✅ Already follows | ⚠️ Partially follows | ❌ Not yet adopted | ➖ Not applicable

---

## 1. State Organization

### SO-01: File-per-domain ✅

**Practice**: Each `.sls` file owns a single domain (audio, fonts, dns, etc.). New functionality goes into the appropriate domain file; new `.sls` files are created only when no existing domain fits.

**Rationale**: Salt's `include` mechanism creates implicit coupling. Fewer, well-scoped files reduce the dependency graph complexity and make it easier to understand what a `just apply desktop` will touch.

**This project**: 44 state files in `states/`, each covering a distinct domain. The orchestrator `states/system_description.sls` (lines 44-98) includes all domains in logical order: core, system, desktop, network, packages, applications, services.

### SO-02: Macro-first for repeated patterns ✅

**Practice**: Common infrastructure patterns (package install, GitHub release download, service management) MUST use project macros from `_macros_*.jinja`. Never inline a pattern already covered by a macro.

**Rationale**: Macros encode network resilience (retry), idempotency guards (creates/unless), consistent naming (install_*, build_*), and parallel execution. Bypassing them loses all four guarantees.

**This project**: 5 macro files covering all repeating patterns:
- `_macros_common.jinja` — shared constants (`retry_attempts=3`, `retry_interval=10`)
- `_macros_github.jinja` — GitHub release downloads
- `_macros_install.jinja` — curl, pip, cargo, zip, tar installs
- `_macros_pkg.jinja` — pacman, paru, PKGBUILD, npm installs
- `_macros_service.jinja` — systemd services, udev rules, directory creation

When a long-lived system service needs a dedicated account or managed runtime/data
paths, prefer the declarative inventory in `states/data/managed_resources.yaml`
plus the shared `states/systemd_resources.sls` rendering path over bespoke
`user.present`, ad-hoc `file.directory`, or one-off `tmpfiles.d` snippets.

See CLAUDE.md "Macros" section for the full reference table.

### SO-03: State ID naming convention ✅

**Practice**: Use `target_descriptor` pattern for state IDs (e.g., `loki_config`, `greetd_enabled`, `rfkill_service_masked`). Never use file paths as state IDs. Exception: `install_*` and `build_*` prefixes are reserved for macro-generated IDs.

**Rationale**: Descriptive IDs make `require` chains readable. File paths as IDs break when files move and are impossible to understand in logs.

**This project**: Consistently applied across all 44 state files. The `name:` parameter is used explicitly when the state ID differs from the target path.

### SO-04: Inline content thresholds ✅

**Practice**: Configs >= 10 lines go to `states/configs/`, systemd units to `states/units/`, scripts to `states/scripts/`. Inline content is reserved for short one-liners.

**Rationale**: Inline multi-line YAML is hard to read, hard to diff, and impossible to lint independently. Separate files get syntax highlighting and can be validated by their native linters.

**This project**: `states/configs/` (template files), `states/units/` (systemd units), `states/scripts/` (shell scripts for `cmd.script`).

### SO-05: Centralized imports ✅

**Practice**: A single `_imports.jinja` file re-exports all macros and constants. State files import one file instead of cherry-picking from multiple macro files.

**Rationale**: Reduces boilerplate. When a macro moves between files, only `_imports.jinja` needs updating.

**This project**: `states/_imports.jinja` (21 lines) re-exports from `_macros_common.jinja` and provides the single import point used by all `.sls` files.

---

## 2. Data Patterns

### DR-01: `import_yaml` over pillar for masterless ✅

**Practice**: In masterless mode, use `import_yaml` for all structured data. Never use pillar.

**Rationale**: Pillar's value is encryption-in-transit and per-minion targeting via a master. In masterless mode, the minion IS the only consumer — pillar overhead (render + encrypt) provides zero benefit. `import_yaml` is rendered locally, faster, and easier to debug.

**This project**: 20+ data files in `states/data/` consumed via `import_yaml`:
- `packages.yaml` — categorized package declarations (360+ packages)
- `versions.yaml` — pinned tool versions
- `installers.yaml` — CLI tool install definitions
- `custom_pkgs.yaml` — local PKGBUILD sources
- `hosts.yaml` — per-host configuration overrides

### DR-02: Per-host configuration via grains + host_config ✅

**Practice**: Use `grains['host']` for host identification. Maintain a central config map that merges defaults with per-host overrides. Expose computed fields (paths, feature flags) as a single `host` object to all states.

**Rationale**: Grains are local, fast, and require no master. A central config map avoids scattering conditionals across state files.

**This project**: `states/host_config.jinja` loads `data/hosts.yaml`, merges defaults with host-specific overrides, and computes derived fields (`pkg_list`, `primary_output`, feature flags). All states reference `{{ host.* }}` for per-host values.

### DR-03: Data file conventions ✅

**Practice**: Package lists in `states/data/*.yaml` MUST use YAML list format (one package per line) with inline comments describing each package. Entries sorted lexicographically by default; logical grouping acceptable for large sets.

**Rationale**: Inline comments are impossible inside YAML folded scalars (`>-`). One-per-line format enables meaningful diffs, grep-ability, and self-documentation.

**This project**: All data files follow this convention. When a data file stores a list consumed as a string by macros, the template uses `| join(' ')` to reconstruct the space-separated string.

See CLAUDE.md "Data file package lists" and "Package descriptions" conventions.

### DR-04: Salt+Chezmoi boundary with lint enforcement ✅

**Practice**: Each config file must have exactly one owner — Salt or Chezmoi. Enforce the boundary with a linter that detects violations automatically.

**Ownership rules**:
- Salt owns files requiring: gopass secrets, service watch triggers, non-XDG deploy paths, grain-conditional deployment
- Chezmoi owns purely declarative user dotfiles
- Files in `dotfiles/` that Salt sources via `salt://dotfiles/` MUST be listed in `.chezmoiignore`
- Files where Salt has a separate template MUST NOT exist in `dotfiles/`

**Rationale**: Dual ownership causes silent overwrite conflicts. The linter catches violations before they reach production.

**This project**: `scripts/lint-ownership.py` (87 lines) enforces this boundary. Runs as part of `just lint`.

---

## 3. Network Resilience

### NR-01: Retry on all network operations ✅

**Practice**: Every state that accesses the network MUST have `retry: {attempts: 3, interval: 10}`. Import values from `_macros_common.jinja` via `_imports.jinja`.

**Rationale**: Network is unreliable. Transient DNS failures, CDN glitches, and rate limits cause flaky applies. Three retries at 10-second intervals handle most transient failures.

**This project**: All macros (`curl_bin`, `github_release_system`, `pacman_install`, `paru_install`, `cargo_pkg`, etc.) include retry automatically. Inline `cmd.run` states that touch the network must apply retry manually.

### NR-02: Parallel independent downloads ✅

**Practice**: Use `parallel: True` on independent download/install states. Never use on states with `require` chains to other installs.

**Rationale**: Sequential downloads serialize network I/O unnecessarily. A typical apply with 50+ downloads benefits significantly from parallelism.

**This project**: Applied in `installers.sls`, `installers_mpv.sls`, `ollama.sls`, and within macros (`curl_bin`, `github_tar`).

### NR-03: Idempotency guard on every download ✅

**Practice**: Every download/install state MUST have `creates:` (file marker) or `unless:` (state check) to avoid re-running on every apply.

**Rationale**: Re-downloading existing binaries wastes bandwidth and time. Without guards, `just apply` takes 30+ minutes instead of seconds on a no-change run.

**This project**: Enforced automatically by all macros. See section 4 (Idempotency) for guard selection guidelines.

### NR-04: Curl flags: always `-fsSL` ✅

**Practice**: All curl commands MUST use `-fsSL`: `-f` fail on HTTP errors, `-sS` silent with errors shown, `-L` follow redirects.

**Rationale**: Without `-f`, curl returns exit 0 on 404 pages, silently saving error HTML as a "binary". Without `-L`, GitHub release URLs (which redirect) fail silently.

**This project**: All macros use `curl -fsSL`. The `_macros_install.jinja` curl_bin macro template (line 25) sets this as the baseline.

---

## 4. Idempotency

### ID-01: Guard selection guide ✅

**Practice**: Every `cmd.run` and `cmd.script` state MUST have a guard. Choose based on what the state produces:

| Guard | When to use | Example |
|-------|-------------|---------|
| `creates:` | State produces a known file | `creates: /etc/udev/rules.d/50-qmk.rules` |
| `unless:` | Result is a system state change | `unless: rg -qx 'steam' {{ pkg_list }}` |
| `onlyif:` | State depends on optional software/hardware | `onlyif: command -v firewall-cmd` |

**Rationale**: Guards are the foundation of idempotent applies. Without them, states re-run on every apply, wasting time and risking breaking a working system.

**This project**: See CLAUDE.md "Idempotency Guards" section for the full reference table.

### ID-02: Prefer `creates:` for simplicity ✅

**Practice**: When a state produces a single file, prefer `creates:` over `unless:`. It's the simplest, most readable guard.

**Rationale**: `creates:` is declarative — Salt checks file existence before running the command. `unless:` requires writing a shell command that returns the right exit code, which is error-prone.

**This project**: Used extensively in `dns.sls` (`creates: /var/lib/unbound/root.key`), `installers.sls` (`creates: {{ home }}/.local/bin/aider`), and all install macros.

### ID-03: Combining `onlyif:` and `unless:` ✅

**Practice**: `onlyif:` and `unless:` can be combined — the state runs only when `onlyif` succeeds AND `unless` fails. Use this for conditional states that also need idempotency.

**Rationale**: Some states should only run when optional software is present (onlyif) AND haven't been completed yet (unless). Combining guards handles both requirements.

**This project**: Used in `network.sls` (firewall rules conditional on `firewall-cmd` being installed).

---

## 5. Testing & Validation

### TV-01: Render validation before apply ✅

**Practice**: Run `just validate` (renders all states, checks for Jinja/YAML errors) before every `just apply`. A state that fails to render will break the entire apply.

**Rationale**: Salt renders all included states before applying any of them. A Jinja syntax error in `fonts.sls` can block `packages.sls` from running, even though they're unrelated.

**This project**: `just validate` renders all 44 states and reports failures. Takes ~65 seconds.

### TV-02: Dry-run with `test=True` ✅

**Practice**: Use `just test STATE` for a dry-run that reports what WOULD change without applying. Essential for reviewing changes before they touch the live system.

**Rationale**: Live workstation — there's no staging environment. `test=True` is the closest thing to a preview.

**This project**: `just test desktop` shows what `desktop.sls` would change. Available for any individual state.

### TV-03: Multi-linter pipeline ✅

**Practice**: Run multiple linters covering different aspects: YAML syntax, Jinja templates, shell scripts, Python code, dotfile conventions, systemd units, file ownership boundaries.

**Rationale**: No single linter catches everything. The combination of 8+ linters covers the full stack from YAML to shell to Python.

**This project**: `just lint` runs: ruff (Python), lint-jinja (custom Jinja validator, 1178 lines), lint-dotfiles, lint-ownership (Salt/Chezmoi boundary), lint-units (systemd), shellcheck, yamllint, taplo (TOML).

### TV-04: Container smoke tests ✅

**Practice**: Test state rendering and safe execution in an isolated container (Podman + archlinux:latest) before applying to the live system.

**Rationale**: Catches import errors, missing dependencies, and template rendering issues without touching the real system.

**This project**: `tests/smoke-test.sh` (164 lines). Run via `just smoke-test`.

### TV-05: Btrfs snapshot rollback ✅

**Practice**: Automatically create btrfs snapshots before and after every apply. Provide one-command rollback.

**Rationale**: Even with testing, applies can produce unexpected results. Instant rollback to the pre-apply state is the ultimate safety net.

**This project**: Every `just apply` creates a snapper pre/post pair. `just rollback` reverts the last pair via `snapper undochange`. Gracefully skipped if snapper is unavailable.

---

## 6. LLM Integration

### LM-01: CLAUDE.md as convention encoder ✅

**Practice**: Maintain a comprehensive CLAUDE.md at the project root that encodes all project conventions, macro references, naming patterns, and workflow requirements. This file is automatically loaded into AI context for every conversation.

**Rationale**: AI tools generate Salt states based on their training data, which includes generic Salt documentation. Project-specific conventions (macro names, guard patterns, path conventions) are NOT in the training data. CLAUDE.md bridges this gap by providing project-specific rules in every conversation.

**This project**: `CLAUDE.md` (343 lines) covers: key paths, all 44 state modules with purpose descriptions, all macros with signatures, network resilience rules, idempotency guard reference, cmd.run vs cmd.script decision tree, naming conventions, commit style, file ownership rules. This is more comprehensive than what any MCP server provides.

### LM-02: Macro documentation for AI consumption ✅

**Practice**: Document every macro with its name, parameters, purpose, and a usage example. Include the parameter defaults and constraints that an AI tool needs to generate correct calls.

**Rationale**: LLMs can't read Jinja macro source reliably (nested Jinja/YAML is confusing). Explicit documentation in CLAUDE.md lets AI tools use macros correctly without parsing the source.

**This project**: CLAUDE.md "Macros" section contains 4 tables (one per macro file) listing every macro with its parameters and purpose. Example usage is shown in the "Conventions" section.

### LM-03: Data-driven patterns reduce AI errors ✅

**Practice**: When adding new packages/tools/services, prefer adding entries to YAML data files over writing new state logic. Data files are simpler for AI tools to modify correctly.

**Rationale**: Adding a line to `packages.yaml` is almost impossible to get wrong. Writing a new `cmd.run` state with correct guards, retry, and naming requires understanding multiple conventions simultaneously.

**This project**: `states/data/packages.yaml` (360+ entries), `states/data/installers.yaml`, `states/data/custom_pkgs.yaml` — AI tools add entries to these files rather than writing new state logic.

### LM-04: Validation loop workflow ✅

**Practice**: After any state change generated by an AI tool, run `just validate` to confirm the change doesn't break any state. This is encoded in CLAUDE.md as a workflow requirement.

**Rationale**: AI-generated Jinja can have subtle errors (wrong variable names, missing imports, broken require chains) that only surface at render time. The validation loop catches these before they reach `just apply`.

**This project**: CLAUDE.md "Workflow Requirements" section mandates running `just` (default: `system_description`) before handing results back to the user.

### LM-05: Constitution as guardrails ✅

**Practice**: Maintain a constitution file (`.specify/memory/constitution.md`) that codifies non-negotiable principles. AI tools check their work against these principles before presenting results.

**Rationale**: Constitution principles are the invariants that must never be violated, regardless of what the user asks. They catch the cases where an AI tool might "helpfully" bypass safety checks.

**This project**: Constitution (version 1.1.0) defines 8 principles: Idempotency, Network Resilience, Secrets Isolation, Macro-First, Minimal Change, Convention Adherence, Verification Gate, CI Gate.

---

## 7. LLM Anti-Patterns

Common mistakes that AI tools produce when generating Salt states for this project, with correct alternatives.

### AP-01: Using pillar in masterless mode

**Root cause**: Salt official documentation prominently features pillar. LLMs over-index on official docs and default to pillar for any data storage.

**Before** (wrong):
```yaml
# pillar/packages.sls — WRONG for masterless
packages:
  - git
  - tmux

# state file
{% set pkgs = salt['pillar.get']('packages', []) %}
install_packages:
  pkg.installed:
    - pkgs: {{ pkgs }}
```

**After** (correct):
```yaml
# states/data/packages.yaml
base:
  - git   # version control system
  - tmux  # terminal multiplexer

# state file
{% import_yaml 'data/packages.yaml' as packages %}
{{ pacman_install('base_packages', packages.base | join(' ')) }}
```

**Why**: Pillar requires a master to render and encrypt. In masterless mode (`salt-call --local`), pillar has zero benefit and adds complexity. `import_yaml` is local, fast, and debuggable.

### AP-02: Missing idempotency guards on `cmd.run`

**Root cause**: LLMs generate `cmd.run` states that look correct but lack guards, causing them to re-run on every apply.

**Before** (wrong):
```yaml
install_tool:
  cmd.run:
    - name: curl -fsSL https://example.com/tool -o /usr/local/bin/tool
```

**After** (correct):
```yaml
install_tool:
  cmd.run:
    - name: curl -fsSL https://example.com/tool -o /usr/local/bin/tool
    - creates: /usr/local/bin/tool
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}
```

**Why**: Without `creates:`, Salt re-downloads the binary on every apply. Without retry, transient network failures break the apply.

### AP-03: `file.managed` without `replace: False` on self-modifying configs

**Root cause**: LLMs don't know which tools rewrite their own config files at startup. They default to `file.managed` which overwrites on every apply.

**Before** (wrong):
```yaml
self_modifying_config:
  file.managed:
    - name: {{ home }}/.config/tool/config.json
    - source: salt://configs/tool.json.j2
    - template: jinja
```

**After** (correct):
```yaml
self_modifying_config:
  file.managed:
    - name: {{ home }}/.config/tool/config.json
    - source: salt://configs/tool.json.j2
    - template: jinja
    - replace: False
```

**Why**: Some tools rewrite their config at startup — adding defaults, metadata, reordering keys. Without `replace: False`, Salt overwrites the tool's changes on every apply, creating a restart loop. This anti-pattern bit this project on a prior Telegram bot gateway.

### AP-04: Hardcoding paths instead of using host_config

**Root cause**: LLMs use literal paths from examples without recognizing that paths are parameterized via `host_config.jinja`.

**Before** (wrong):
```yaml
my_config:
  file.managed:
    - name: /home/alice/.config/myapp/config.toml
    - user: alice
    - group: alice
```

**After** (correct):
```yaml
my_config:
  file.managed:
    - name: {{ home }}/.config/myapp/config.toml
    - user: {{ user }}
    - group: {{ user }}
```

**Why**: `{{ home }}` and `{{ user }}` are imported from `_macros_common.jinja` via `_imports.jinja`. Hardcoding paths breaks portability and violates the DRY principle.

### AP-05: Creating new `.sls` files instead of extending existing domains

**Root cause**: LLMs treat each request as isolated. "Add a new service" triggers file creation rather than extending the appropriate domain file.

**Before** (wrong):
```
# Creating states/my_new_tool.sls for a single pip install
```

**After** (correct):
```
# Add to states/installers.sls or states/data/installers.yaml
# since it's a CLI tool install — that's the domain
```

**Why**: Each `.sls` file must be added to `system_description.sls` include list. Proliferating files for small additions increases the dependency graph and maintenance burden. Use existing domain files.

### AP-06: Using pip/npm/cargo instead of pacman macros

**Root cause**: LLMs default to language-native package managers. Salt docs don't emphasize distribution packages.

**Before** (wrong):
```yaml
install_bat:
  cmd.run:
    - name: cargo install bat
    - unless: command -v bat
```

**After** (correct):
```yaml
{{ pacman_install('bat', 'bat') }}
```

**Why**: Arch/CachyOS packages are pre-compiled, tracked by pacman, and auto-updated with `pacman -Syu`. Language-native installs (pip, npm, cargo) are untracked, require manual updates, and may conflict with system packages. Use pacman/paru macros unless the package genuinely doesn't exist in repos or AUR.

---

## 8. Ecosystem Health

### Salt Project Timeline (2023-2026)

| Date | Event | Impact |
|------|-------|--------|
| 2023-11 | Broadcom acquires VMware (SaltStack parent) | Medium — governance uncertainty |
| 2024-06 | Salt 3007.0 (STS) released | Low — normal release cycle |
| 2024-09 | Community manager Jimmy Chunga departs; no replacement | Medium — community engagement declines |
| 2024-10 | Salt Project AWS account/CI infrastructure deleted | High — halted CI, community trust damaged |
| 2024-11 | Package repos migrate to `packages.broadcom.com` | Low — URL change only |
| 2024-12 | POP Project and Idem Project archived | Low — this project doesn't use them |
| 2025-01 | Tom Hatch exits Broadcom, commits to staying with Salt | Medium — key person retained |
| 2025-01 | GitHub Discussion #67028: soft fork discussed | Medium — community preparing contingency |
| 2025 H1 | Great Module Migration begins (cloud modules → salt-extensions) | None — this project uses core modules only |
| 2025 H2 | Salt 3008 LTS expected | Low — core modules remain in-tree |

### Risk Assessment for This Project

**Risk level: LOW**

This project is well-insulated from Salt's ecosystem challenges:

1. **Core modules only**: Uses `file`, `cmd`, `service`, `pkg` — all staying in Salt core. No cloud provider modules, no exotic execution modules.
2. **Masterless mode**: No dependency on Salt master infrastructure, job reporting, or event bus.
3. **Single workstation**: No fleet management, no minion targeting, no pillar encryption needs.
4. **Self-contained state tree**: Version-controlled, no external formula dependencies.

**Watch signals**:
- If Salt 3008 LTS is delayed beyond 2025 → evaluate pyinfra as backup
- If core modules (file, cmd, service) are moved to extensions → serious risk escalation
- If GitHub Discussion #67028 results in a fork → evaluate fork adoption

### Modules Used by This Project

All modules used are in Salt core and confirmed to remain there through 3008+:

| Module | Category | Used for |
|--------|----------|----------|
| `file.managed`, `file.symlink`, `file.directory` | File | Config deployment, symlinks |
| `cmd.run`, `cmd.script` | Execution | Package installs, builds, system commands |
| `service.enabled`, `service.running` | Service | Systemd service management |
| `pkg.installed` | Package | Direct pacman installs (rare — macros preferred) |
| `kmod.present` | Kernel | Kernel module loading |
| `sysctl.present` | System | Kernel parameter tuning |
| `mount.mounted` | Filesystem | Disk mounts |

---

## 9. Alternatives Assessment

| Tool | Strengths | Weaknesses | Migration Feasibility |
|------|-----------|------------|----------------------|
| **Ansible** | Agentless (SSH), large community, Red Hat backing, MCP servers exist | Slower execution, no event bus, YAML-only logic | **Medium** — Playbook per .sls, Jinja reusable. High effort for roles/collections migration. |
| **pyinfra** | Python-native, fast, modern design, small footprint | Small community, no formula ecosystem, limited docs | **Medium** — Pythonic API maps well to Salt states. Risk: project maturity. |
| **NixOS** | Truly declarative, atomic rollbacks, reproducible | Steep learning curve, already migrated away from Nix | **Low** — Re-adoption unlikely. Nix language is fundamentally different from Salt's model. |
| **Pulumi** | Real programming languages, AI-native IaC | Cloud-focused, overkill for workstation, vendor lock-in | **Low** — Wrong tool for the job. Designed for cloud infrastructure, not workstation config. |
| **Chezmoi (alone)** | Best-in-class dotfile management | Only handles user dotfiles, not system config | **N/A** — Already used alongside Salt. Cannot replace Salt's system-level management. |

**Recommendation**: Stay with Salt. The masterless, core-only setup avoids all risk areas. If Salt becomes unmaintained, pyinfra is the most viable migration target — similar imperative model, Python-native, actively developed.

---

## 10. Compliance Summary

| ID | Practice | Status |
|----|----------|--------|
| SO-01 | File-per-domain organization | ✅ |
| SO-02 | Macro-first for repeated patterns | ✅ |
| SO-03 | State ID naming convention | ✅ |
| SO-04 | Inline content thresholds | ✅ |
| SO-05 | Centralized imports | ✅ |
| DR-01 | `import_yaml` over pillar | ✅ |
| DR-02 | Per-host config via grains + host_config | ✅ |
| DR-03 | Data file conventions (list format, comments, sort) | ✅ |
| DR-04 | Salt+Chezmoi boundary with lint enforcement | ✅ |
| NR-01 | Retry on all network operations | ✅ |
| NR-02 | Parallel independent downloads | ✅ |
| NR-03 | Idempotency guard on every download | ✅ |
| NR-04 | Curl flags: always `-fsSL` | ✅ |
| ID-01 | Guard selection guide | ✅ |
| ID-02 | Prefer `creates:` for simplicity | ✅ |
| ID-03 | Combining `onlyif:` and `unless:` | ✅ |
| TV-01 | Render validation before apply | ✅ |
| TV-02 | Dry-run with `test=True` | ✅ |
| TV-03 | Multi-linter pipeline | ✅ |
| TV-04 | Container smoke tests | ✅ |
| TV-05 | Btrfs snapshot rollback | ✅ |
| LM-01 | CLAUDE.md as convention encoder | ✅ |
| LM-02 | Macro documentation for AI consumption | ✅ |
| LM-03 | Data-driven patterns reduce AI errors | ✅ |
| LM-04 | Validation loop workflow | ✅ |
| LM-05 | Constitution as guardrails | ✅ |
| AP-01 | Avoid pillar in masterless mode | ✅ |
| AP-02 | Always add idempotency guards | ✅ |
| AP-03 | Use `replace: False` for self-modifying configs | ✅ |
| AP-04 | Use host_config variables, not hardcoded paths | ✅ |
| AP-05 | Extend existing domains, don't create new files | ✅ |
| AP-06 | Prefer pacman/paru over pip/npm/cargo | ✅ |
