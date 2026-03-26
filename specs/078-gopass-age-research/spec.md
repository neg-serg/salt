# Feature Specification: Gopass Age Backend Failure Research

**Feature Branch**: `078-gopass-age-research`  
**Created**: 2026-03-26  
**Status**: Draft  
**Input**: User description: "Посмотри в интернете почему текущий gopass age backend может не работать и какие есть симптомы, для этого нужно провести исследование первичных источников и определить, можно ли довести текущий способ до рабочего состояния или нужна миграция на другой backend"

## Clarifications

### Session 2026-03-26

- Q: What exact threshold defines the current backend as salvageable for this feature? → A: Only if both non-interactive `gopass show` and `chezmoi apply` succeed on the current machine without a new passphrase prompt.
- Q: If migration is required, what is the minimum next decision this feature should hand off? → A: Choose the target backend first, rather than assuming either `gpg` or another `age` strategy in advance.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Diagnose the current failure mode (Priority: P1)

As an operator, I need an evidence-backed diagnosis of why the current `gopass` + `age` backend repeatedly asks for a passphrase so I can stop treating this as a random local glitch.

**Why this priority**: Without a concrete diagnosis, every rollout and every `chezmoi` call remains blocked by repeated secret prompts and the team risks applying destructive experiments to the password store.

**Independent Test**: Can be fully tested by comparing upstream primary sources with the current host behavior and producing a single diagnosis that explains the repeated prompt and non-interactive failure mode.

**Acceptance Scenarios**:

1. **Given** the current host has `gopass 1.16.1`, `age.agent-enabled = true`, and an encrypted `~/.config/gopass/age/identities`, **When** the investigation is completed, **Then** it MUST explain why `gopass show` still prompts or fails after `gopass age agent unlock`.
2. **Given** the current host reproduces `pinentry error: could not get state of terminal: inappropriate ioctl for device`, **When** the investigation is completed, **Then** it MUST classify that symptom as interactive-only vs non-interactive and explain the operational impact on `chezmoi apply`.

---

### User Story 2 - Enumerate recognizable symptoms (Priority: P2)

As an operator, I need a symptom matrix for this backend so I can quickly recognize whether another machine is hitting the same failure class before attempting a migration.

**Why this priority**: The same root cause can present as pinentry failures, stuck unlock flows, or agent confusion, and operators need a stable checklist rather than ad hoc memory.

**Independent Test**: Can be fully tested by mapping local observations to distinct symptom categories and showing which ones are corroborated by upstream sources versus only observed locally.

**Acceptance Scenarios**:

1. **Given** local observations from interactive and non-interactive shells, **When** the symptom matrix is produced, **Then** each symptom MUST include the exact trigger condition and expected command output pattern.
2. **Given** upstream sources that discuss `age` passphrase caching and identity handling, **When** the symptom matrix is produced, **Then** it MUST distinguish upstream-confirmed limitations from local-only observations.

---

### User Story 3 - Decide whether salvage is realistic (Priority: P3)

As an operator, I need a decision on whether the current `age` backend path can be made reliable enough for unattended rollouts or whether a migration path should be prepared instead.

**Why this priority**: The research is only useful if it leads to a clear operational decision rather than a collection of disconnected notes.

**Independent Test**: Can be fully tested by evaluating the current backend against explicit reliability criteria for unattended secret access and documenting whether those criteria are satisfiable without backend migration.

**Acceptance Scenarios**:

1. **Given** the investigated upstream evidence and local reproductions, **When** the conclusion is written, **Then** it MUST state whether the current backend is considered salvageable for unattended rollout use.
2. **Given** the conclusion is "not salvageable", **When** the research output is reviewed, **Then** it MUST identify the minimum next decision needed for migration planning.

### Edge Cases

- Upstream sources may describe incremental improvements such as `age agent unlock` while still leaving passphrase caching behavior incomplete for unattended workflows.
- The host may contain unrelated stale configuration, such as a removed `ageimport` mount warning, that is noisy but not causal for the repeated prompt.
- Interactive and non-interactive contexts may diverge: a TTY can show a passphrase prompt while a non-interactive process fails immediately with pinentry/IOCTL errors.
- Local experiments can temporarily damage `~/.config/gopass/age/identities`; the research MUST separate store corruption from upstream design limitations.
- A source may describe generic `age` behavior that does not exactly match how `gopass` wraps encrypted identity files; such mismatches MUST be called out explicitly.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The research output MUST capture the exact local environment relevant to the failure, including `gopass` version, active `age` settings, identity file format, and the failing command shapes.
- **FR-002**: The research output MUST use primary sources from upstream projects or official documentation to explain expected `gopass` + `age` behavior.
- **FR-003**: The research output MUST document the currently observed local symptoms, including repeated passphrase requests, non-interactive pinentry failure, and the effect on `chezmoi`-driven rollout steps.
- **FR-004**: The research output MUST distinguish between symptoms that are confirmed by upstream discussion or documentation and symptoms that are only observed locally on this machine.
- **FR-005**: The research output MUST explain the role of the encrypted `~/.config/gopass/age/identities` file and why naive conversion to a plaintext `AGE-SECRET-KEY-...` file does not constitute a validated fix for the current setup.
- **FR-006**: The research output MUST evaluate whether `gopass age agent unlock` is sufficient to make unattended secret access reliable in the current setup.
- **FR-006A**: The research output MUST treat the current backend as salvageable only if both non-interactive `gopass show` and `chezmoi apply` succeed on the current machine without a new passphrase prompt.
- **FR-007**: The research output MUST conclude with an operational decision statement: either the current backend can be made reliable enough for unattended rollout use, or migration planning is required.
- **FR-008**: The research output MUST identify the minimum follow-up decision needed if migration is required, without prescribing implementation details that belong in later planning.
- **FR-008A**: If migration is required, the minimum next decision MUST be choosing the target backend first, rather than assuming either `gpg` or another `age` strategy in advance.
- **FR-009**: The research output MUST avoid destructive changes to the password store during the investigation and MUST treat backup or rollback needs as first-class constraints.
- **FR-010**: The research output MUST record explicit unknowns where upstream evidence is incomplete, contradictory, or insufficient to explain a local symptom.

### Key Entities *(include if feature involves data)*

- **Upstream Evidence**: A primary-source statement from `gopass` or `age` maintainers, release notes, or official documentation that constrains what behavior is expected.
- **Local Symptom**: A reproducible command result on the current host, including environment preconditions, command shape, and failure text.
- **Failure Hypothesis**: A reasoned explanation linking one or more local symptoms to upstream evidence, with confidence noted as confirmed, inferred, or unresolved.
- **Operational Decision**: The final recommendation about whether the existing backend can support unattended rollout usage or requires migration planning.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The completed research cites at least three primary sources that directly discuss `gopass` `age` behavior, agent behavior, or encrypted identity handling.
- **SC-002**: Every locally observed symptom included in the final research output is labeled as either upstream-confirmed, locally reproduced but not upstream-confirmed, or unresolved.
- **SC-003**: A reviewer can determine within five minutes whether the current backend is considered salvageable for unattended rollout use and why.
- **SC-004**: The research output identifies at least one explicit stop condition that would justify migration planning instead of continued debugging of the current backend.

## Research Inputs

- Local host observations gathered on 2026-03-26 from `gopass 1.16.1`, including:
  - `gopass config` showing `age.agent-enabled = true` and `age.agent-timeout = 3600`
  - `file ~/.config/gopass/age/identities` reporting `age encrypted file, scrypt recipient (N=2**18)`
  - `gopass show -o email/gmail/address` failing non-interactively with `pinentry error: could not get state of terminal: inappropriate ioctl for device`
  - prior `strace` evidence that `gopass show` connects to `gopass-age-agent.sock` and then still opens `~/.config/gopass/age/identities`
- Primary-source URLs to anchor the research:
  - `https://github.com/gopasspw/gopass/discussions/3085`
  - `https://github.com/gopasspw/gopass/discussions/3032`
  - `https://github.com/gopasspw/gopass/releases/tag/v1.16.0`
  - `https://github.com/FiloSottile/age`
