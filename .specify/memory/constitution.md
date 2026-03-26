<!--
  Sync Impact Report
  Version change: 1.2.0 → 1.3.0
  Modified principles:
    - III. Secrets Isolation → III. Secrets Isolation
  Added sections: None
  Removed sections: None
  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ (Constitution Check aligns with principles)
    - .specify/templates/spec-template.md ✅ (no changes needed)
    - .specify/templates/tasks-template.md ✅ (no changes needed)
    - README.md ✅ (top-level secrets wording generalized)
    - .specify/templates/commands/*.md ✅ (directory absent; no command template updates required)
  Follow-up TODOs:
    - Update operator secret-management docs during feature implementation if the project migrates active workflows to the hardware-backed age plugin path
-->

# Salt Project Constitution

## Core Principles

### I. Idempotency (NON-NEGOTIABLE)

Every `cmd.run` and `cmd.script` state MUST have a guard to prevent re-execution on subsequent applies. Acceptable guards:

- `creates:` when the state produces a known file
- `unless:` when the result is a system state change (package installed, group membership, kernel module loaded)
- `onlyif:` to conditionally skip states that depend on optional software or hardware

States without guards cause unnecessary work on every apply, waste time, and risk breaking a working system. Macros (`_macros_install.jinja`, `_macros_github.jinja`, `_macros_pkg.jinja`) enforce this automatically; inline `cmd.run` states MUST apply guards manually.

### II. Network Resilience

All states that access the network MUST follow these rules:

- **Retry**: `retry: {attempts: retry_attempts, interval: retry_interval}` (imported from `_imports.jinja`)
- **Parallel**: `parallel: True` on independent download/install states (never on states with `require` chains)
- **Idempotency guard**: every download/install state MUST have `creates:` or `unless:`
- **Curl flags**: always `curl -fsSL` (fail on HTTP errors, silent with errors, follow redirects)

Network is unreliable. States that silently fail on transient errors, re-download existing files, or serialize independent downloads waste time and produce flaky applies.

### III. Secrets Isolation

No plaintext secrets MUST exist in the repository. All secrets MUST use `gopass`
with an approved encrypted backend. Approved backends are:

- `gpg` with hardware-backed access such as YubiKey
- `age` with password-protected identities and documented backup/recovery handling
- `age` with hardware-backed plugin identities such as YubiKey and documented
  unlock, backup, and recovery handling

- Chezmoi templates: `{{ gopass "key/path" }}` in `.tmpl` files
- Salt states: `gopass show -o key/path` in `cmd.run`
- Fallback pattern when gopass is inaccessible: parse existing config files with `ignore_retcode: True`
- Backend migrations MUST preserve secret path stability, maintain one active source of
  truth, define rollback artifacts, and update operator documentation before legacy access
  is retired

A single leaked secret compromises the entire workstation. The `gopass` chain ensures
secrets remain encrypted at rest; approved backends are allowed only when their unlock,
backup, and recovery properties are explicitly documented and verified.

### IV. Macro-First

Repeating infrastructure patterns (package install, GitHub release download, service management) MUST use the project's Jinja macros from `_macros_*.jinja`. Inline implementations of patterns already covered by macros are prohibited.

Macros encode all four network resilience rules, idempotency guards, and consistent state ID naming (`install_*`, `build_*`). Bypassing them loses these guarantees and creates maintenance burden.

### V. Minimal Change

Changes MUST be limited to what is directly requested or clearly necessary:

- No speculative features, extra configurability, or "improvements" beyond scope
- No docstrings, comments, or type annotations to code not being changed
- No error handling for scenarios that cannot happen
- No abstractions for one-time operations
- No backwards-compatibility shims when the code can be changed directly

Over-engineering a configuration management system increases surface area for breakage. Three similar lines are better than a premature abstraction.

### VI. Convention Adherence

All contributions MUST follow established conventions:

- **State IDs**: `target_descriptor` pattern (e.g., `loki_config`, `greetd_enabled`). Never use file paths as state IDs
- **Commit style**: `[scope] imperative description` where scope matches what changed (e.g., `[nvim] add formatter toggle`, `[zsh] fix PATH order`, `[dns] refresh blocklist`); multiple scopes are allowed when the change genuinely spans them, and subjects must not end with a period
- **Shell scripts**: `#!/usr/bin/env zsh` for all scripts in `dotfiles/dot_local/bin/`
- **Inline content thresholds**: configs >=10 lines go to `configs/`, systemd units to `units/`, scripts to `scripts/`
- **Documentation**: English primary, Russian `.ru.md` translation for each doc in `docs/`
- **URL opening**: `handlr open`, never `xdg-open`
- **XDG paths**: custom short paths (`~/music`, `~/pic`, `~/vid`, `~/doc`, `~/dw`), never canonical defaults

Conventions exist because past debugging revealed their necessity (e.g., zsh shebang ensures `.zshenv` is sourced from Hyprland keybinds; `handlr open` works around xdg-open not recognizing Hyprland).

### VII. Verification Gate

Before presenting results, `just` (default target: `system_description`) MUST be run to confirm Salt renders successfully. No state change is considered complete until a clean apply/log is captured.

Salt states are interconnected through `require` chains and `include` lists. A change that renders one state can break another through implicit dependencies. The verification gate catches regressions before they reach the live system.

### VIII. CI Gate

CI MUST pass before work is considered accepted. Pull requests and branches with failing CI are not mergeable and the work is treated as incomplete.

Exceptional circumstances (CI infrastructure outage, flaky test unrelated to the change, upstream dependency breakage) MAY justify merging with failing CI, but MUST be explicitly acknowledged and documented in the commit or PR description with a rationale for the override.

The verification gate (Principle VII) catches local regressions; the CI gate catches integration regressions across the full state tree and ensures reproducibility beyond the developer's machine.

## Platform Constraints

- **OS**: CachyOS (Arch-based). Salt manages both package installation (via pacman/paru macros) and configuration
- **Containers**: Podman (not Docker). All container operations use `podman`
- **Bootloader**: Limine. Kernel params managed via `/boot/limine.conf`
- **User paths**: `/home/<user>` for home, `/mnt/one` and `/mnt/zero` for external storage
- **Build containers**: `archlinux:latest`, ephemeral (`--rm`)
- **zsh reserved variables**: Never use `path`, `status`, `reply`, `match`, `prompt`, `cdpath`, `fpath`, `mailpath`, `manpath`, `module_path`, `fignore`, `argv`, `argc`, `signals`, `pipestatus` as user variables in scripts

## Development Workflow

1. **Read before modify**: Understand existing code before suggesting changes. Use CLAUDE.md and macro documentation as primary reference
2. **Data-driven when possible**: Package lists, service definitions, and font sets live in `states/data/*.yaml` and are consumed via `import_yaml`. Prefer adding entries to data files over writing new state logic
3. **Self-modifying configs**: Some tools (e.g., OpenClaw) rewrite their own config at startup. Use `replace: False` in `file.managed` to deploy initial seed only
4. **State file organization**: Each `.sls` file owns a domain (audio, fonts, dns, etc.). New functionality goes into the appropriate domain file; new `.sls` files are created only when no existing domain fits
5. **Quickshell context**: When working under `dotfiles/dot_config/quickshell/`, load the knowledge-base router from `IMPROVEMENT_PROMPT.md`

## Governance

This constitution supersedes ad-hoc practices. All state changes, script additions, and configuration modifications MUST comply with these principles. Amendments require:

1. Documented rationale for the change
2. Update to this constitution file with version bump
3. Verification that dependent templates (plan, spec, tasks) remain consistent

Versioning follows semantic versioning: MAJOR for principle removals/redefinitions, MINOR for new principles or material expansions, PATCH for clarifications and wording fixes.

**Version**: 1.3.0 | **Ratified**: 2026-03-08 | **Last Amended**: 2026-03-26
