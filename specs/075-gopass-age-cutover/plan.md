# Implementation Plan: Gopass Age Cutover

**Branch**: `075-gopass-age-cutover` | **Date**: 2026-03-26 | **Spec**: [spec.md](/home/neg/src/salt/specs/075-gopass-age-cutover/spec.md)
**Input**: Feature specification from `/specs/075-gopass-age-cutover/spec.md`

## Summary

Execute an immediate live cutover of the active `gopass` store from the current GPG/YubiKey backend to an `age` backend with password-protected identities, while preserving the `gopass` CLI as the only public interface for Salt, chezmoi, scripts, and operator workflows. The design uses a fail-closed sequence with baseline capture, current-host validation, rollback-ready backup artifacts, representative special-entry checks, immediate post-cutover `chezmoi` verification, and a fixed stabilization window before legacy access may be retired.

## Technical Context

**Language/Version**: Markdown, YAML, Bash/Zsh operator workflows, `gopass` 1.16.x  
**Primary Dependencies**: `gopass`, `age`, existing git-backed password store, chezmoi, Salt masterless workflow, spec-kit artifacts  
**Storage**: File-based `gopass` store plus git history and offline rollback artifacts  
**Testing**: `just validate`, representative `gopass` CLI reads, immediate `chezmoi` apply validation, rollback acceptance checks  
**Target Platform**: Single-operator Linux workstation running CachyOS/Arch-compatible userspace  
**Project Type**: Operational migration cutover plan and repository design artifacts  
**Performance Goals**: Complete the live cutover and first successful post-cutover `chezmoi apply` in one operator session; keep required secret-dependent workflows usable throughout the same day  
**Constraints**: Keep `gopass` interface and secret paths stable; one active store at all times; fail closed before cutover acceptance; retain legacy path throughout stabilization; do not rewrite git history during the main cutover  
**Scale/Scope**: One primary password store, one maintainer/operator, one workstation session, documented high-priority consumers in docs, scripts, chezmoi templates, Salt states, and a representative special-entry subset

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Idempotency**: Pass. This feature defines an operator-driven migration workflow and planning artifacts; it does not add unguarded Salt execution semantics.
- **II. Network Resilience**: Pass. No networked Salt states are introduced or changed by the design.
- **III. Secrets Isolation**: Pass with explicit focus. The design keeps plaintext out of the repository, preserves `gopass` as the public interface, uses an approved `age` backend, and requires documented backup, rollback, and recovery handling before legacy access is retired.
- **IV. Macro-First**: Pass. No repeated Salt implementation pattern is proposed.
- **V. Minimal Change**: Pass. Scope is limited to the cutover workflow, validation boundary, rollback evidence, and operator-facing design artifacts directly needed for the migration.
- **VI. Convention Adherence**: Pass. English-primary planning artifacts remain canonical and downstream operator docs remain subject to the English-plus-Russian documentation convention.
- **VII. Verification Gate**: Pending final local verification after artifact generation.
- **VIII. CI Gate**: Pass for planning stage; any future implementation remains CI-gated.

**Gate Result (Pre-Research)**: PASS

## Project Structure

### Documentation (this feature)

```text
specs/075-gopass-age-cutover/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── cutover-checkpoints.md
│   ├── rollback-acceptance.md
│   └── validation-matrix.yaml
└── tasks.md
```

### Source Code (repository root)

```text
docs/
├── deploy-cachyos.md
├── gopass-setup.md
├── secrets-scheme.md
└── *.ru.md

scripts/
├── deploy-cachyos.sh
└── salt-apply.sh

states/
├── mpd.sls
├── opencode.sls
├── openclaw_agent.sls
└── telethon_bridge.sls

specs/075-gopass-age-cutover/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
```

**Structure Decision**: This feature is operations- and documentation-centric. Design artifacts live under `specs/075-gopass-age-cutover/`, while the workflow they constrain spans `docs/`, `scripts/`, and the secret-consuming Salt states under `states/`. No new runtime module tree is introduced.

## Phase 0: Research Summary

- Preserve `gopass` as the only public secret interface and migrate only the crypto backend.
- Use immediate live cutover on the current host, but only after baseline capture and rollback package preparation.
- Treat current-session `chezmoi` success as a required cutover acceptance check, not an optional post-step.
- Preserve secret paths and plaintext equivalence exactly.
- Keep representative attached-file and non-password entries inside the validation boundary.
- Keep the legacy GPG/YubiKey path available throughout the stabilization window.
- Retain current git history during the main cutover and record residual-history handling as a follow-up decision.

## Phase 1: Design Outputs

- `research.md`: concrete design decisions and rejected alternatives for immediate live cutover
- `data-model.md`: entities for active store state, validation cases, rollback package, unlock artifacts, special-entry subset, and stabilization evidence
- `contracts/cutover-checkpoints.md`: go/no-go gates from precheck through stabilization exit
- `contracts/rollback-acceptance.md`: rollback evidence and success conditions
- `contracts/validation-matrix.yaml`: representative validation cases across CLI, chezmoi, Salt, scripts, special entries, and repo validation
- `quickstart.md`: operator workflow for baseline capture, live cutover, immediate verification, rollback triggers, and stabilization

## Post-Design Constitution Check

- **I. Idempotency**: Pass. No new state execution behavior is introduced.
- **II. Network Resilience**: Pass. No networked state behavior changes.
- **III. Secrets Isolation**: Pass. The design keeps secrets out of the repo, uses an approved backend, and requires documented backup/recovery/retirement handling.
- **IV. Macro-First**: Pass. No macro bypass proposed.
- **V. Minimal Change**: Pass. Design remains tightly scoped to the requested cutover workflow.
- **VI. Convention Adherence**: Pass. Artifacts stay within the repository’s established planning and documentation structure.
- **VII. Verification Gate**: Pass after local `just` verification.
- **VIII. CI Gate**: Pass for planning stage; later implementation remains subject to CI.

**Gate Result (Post-Design)**: PASS
