# Implementation Plan: Gopass Age Backend Failure Research

**Branch**: `078-gopass-age-research` | **Date**: 2026-03-26 | **Spec**: [spec.md](/home/neg/src/salt/specs/078-gopass-age-research/spec.md)
**Input**: Feature specification from `/specs/078-gopass-age-research/spec.md`

## Summary

Produce a primary-source-backed diagnosis of the current `gopass` + `age` backend failure on this workstation, with emphasis on repeated passphrase prompting, non-interactive `pinentry` failure, and whether the current backend can be made reliable enough for unattended rollout workflows. The clarified acceptance boundary is strict: the backend is only considered salvageable if both non-interactive `gopass show` and `chezmoi apply` succeed on the current machine without a new passphrase prompt. If that threshold is not met, the handoff from this feature is not a cutover plan to a preselected destination but a decision feature that chooses the target backend first.

## Technical Context

**Language/Version**: Markdown, shell command evidence, `gopass` 1.16.1, `age`-backed store observations  
**Primary Dependencies**: `gopass`, `age`, GitHub upstream discussions/releases, local `gopass` configuration and CLI behavior, spec-kit artifacts  
**Storage**: File-based `gopass` store plus local encrypted `~/.config/gopass/age/identities` and captured command outputs  
**Testing**: Primary-source review, reproducible local `gopass` commands, symptom classification matrix, final decision review against spec success criteria, `just` verification gate, CI status capture  
**Target Platform**: Single-user CachyOS/Arch workstation with `chezmoi` and Salt workflows dependent on `gopass`  
**Project Type**: Internal operational research and decision package  
**Performance Goals**: Reviewer can determine within five minutes whether the backend is salvageable for unattended rollout use; no additional destructive secret-store mutations during research  
**Constraints**: No plaintext secrets in repo; no destructive store experiments; preserve rollback ability; distinguish upstream-confirmed behavior from local-only observations; treat the backend as salvageable only if both non-interactive `gopass show` and `chezmoi apply` succeed without a new prompt; if migration is required, the next feature must choose the target backend first  
**Scale/Scope**: One active workstation, one active `gopass` store, one current backend path under investigation, and one follow-up decision on whether migration planning is required

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Idempotency**: Pass. This feature creates research/design artifacts only and does not introduce Salt state execution.
- **II. Network Resilience**: Pass. Internet usage is limited to source research, not Salt state behavior.
- **III. Secrets Isolation**: Pass with explicit caution. The investigation concerns an approved encrypted backend, forbids plaintext secrets in the repository, and treats backup/recovery constraints as part of the research scope.
- **IV. Macro-First**: Pass. No Salt implementation pattern is introduced.
- **V. Minimal Change**: Pass. Scope is limited to diagnosis, symptom taxonomy, and a backend decision boundary.
- **VI. Convention Adherence**: Pass. Artifacts remain English-primary and confined to spec-kit planning outputs.
- **VII. Verification Gate**: Pass only after local `just` is rerun and captured in `verification.md`.
- **VIII. CI Gate**: Pass only after CI status or explicit override rationale is recorded in `verification.md`.

**Gate Result (Pre-Research)**: PASS

## Project Structure

### Documentation (this feature)

```text
specs/078-gopass-age-research/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── evidence-matrix.md
├── findings.md
├── symptom-matrix.md
├── decision.md
├── verification.md
└── tasks.md
```

### Source Code (repository root)

```text
.specify/
├── memory/constitution.md
└── templates/

docs/
├── gopass-setup.md
├── gopass-setup.ru.md
├── secrets-scheme.md
└── secrets-scheme.ru.md

scripts/
└── salt-apply.sh

specs/
├── 072-gopass-age-migration/
├── 075-gopass-age-cutover/
└── 078-gopass-age-research/

states/
└── [secret-consuming states referenced by docs and rollout workflow]
```

**Structure Decision**: This feature is a research-only documentation package. The primary artifacts live under `specs/078-gopass-age-research/`, while supporting evidence comes from existing `docs/`, `scripts/`, and local host observations. No interface contracts are generated because the feature exposes no new external API, CLI schema, or runtime protocol.

## Phase 0: Research Summary

- Treat upstream maintainer statements about `age` passphrase caching and lack of a full GPG-agent replacement as decision-shaping evidence, not incidental commentary.
- Treat the current workstation symptom set as a combined interactive and non-interactive failure class, not a single `pinentry` misconfiguration.
- Preserve the encrypted `age` identities model during investigation; do not treat plaintext `AGE-SECRET-KEY-...` conversion as a validated workaround for this environment.
- Use `chezmoi` and secret-consuming rollout workflows as the acceptance boundary for unattended usability.
- Consider the backend salvageable only if both non-interactive `gopass show` and `chezmoi apply` succeed on the current machine without a new passphrase prompt.
- If the threshold is not met, stop at a target-backend selection decision instead of assuming a preselected migration destination.

## Phase 1: Design Outputs

- `research.md`: primary-source-backed decisions, rationale, and rejected alternatives
- `data-model.md`: entities for evidence, symptoms, hypotheses, reproduction cases, and operational decisions
- `quickstart.md`: operator workflow to reproduce the investigation and decide whether migration planning should start
- `evidence-matrix.md`: frozen inventory of local baseline facts plus upstream primary-source evidence
- `findings.md`: diagnosis narrative and consolidated failure hypothesis
- `symptom-matrix.md`: trigger/output/status matrix for recognizable backend symptoms
- `decision.md`: salvage-vs-migration verdict, stop condition, and minimum next decision
- `verification.md`: acceptance evidence for non-destructive constraints, `just` verification, and CI status
- `contracts/`: intentionally omitted because this feature is internal research with no external interface contract

## Post-Design Constitution Check

- **I. Idempotency**: Pass. No Salt execution semantics introduced.
- **II. Network Resilience**: Pass. No networked state behavior changed.
- **III. Secrets Isolation**: Pass. The design keeps secrets out of the repo and treats unsafe experiments as out of scope.
- **IV. Macro-First**: Pass. No macro bypass proposed.
- **V. Minimal Change**: Pass. Artifacts stay within diagnosis and planning boundaries.
- **VI. Convention Adherence**: Pass. English-primary spec-kit artifacts preserved.
- **VII. Verification Gate**: Pass after local `just` verification is captured.
- **VIII. CI Gate**: Pass after CI status or documented override rationale is captured.

**Gate Result (Post-Design)**: PASS
