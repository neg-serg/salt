# Data Model: Gopass Age Backend Failure Research

## Entity: UpstreamEvidence

- **Purpose**: Represent one primary-source statement that constrains expected `gopass` `age` backend behavior.
- **Fields**:
  - `id` (string): Stable evidence identifier such as `discussion-3085-passphrase-caching`.
  - `source_type` (enum): `discussion | release_note | official_doc`.
  - `source_url` (string): Canonical upstream URL.
  - `statement_date` (date): Date of the maintainer or release statement.
  - `topic` (enum): `passphrase_caching | agent_behavior | identities_handling | backend_support`.
  - `claim_summary` (string): Condensed claim used in the research output.
  - `confidence` (enum): `direct | inferred`.
- **Validation rules**:
  - Each evidence record must point to a primary source.
  - Direct maintainer statements take precedence over third-party interpretation.

## Entity: LocalSymptom

- **Purpose**: Represent one reproducible symptom observed on the current workstation.
- **Fields**:
  - `id` (string): Stable symptom identifier such as `noninteractive-pinentry-ioctl`.
  - `context` (enum): `interactive_tty | noninteractive_shell | rollout_path`.
  - `trigger_command` (string): Exact command or workflow trigger.
  - `preconditions` (list[string]): Relevant environment facts required before reproduction.
  - `observed_output` (string): Failure text or concise behavioral result.
  - `severity` (enum): `blocking | degraded | informational`.
  - `upstream_status` (enum): `confirmed | partially_confirmed | local_only | unresolved`.
- **Validation rules**:
  - Each symptom must include enough preconditions to be rerun later.
  - Blocking symptoms must map to at least one workflow impacted by the decision boundary.

## Entity: ReproductionCase

- **Purpose**: Represent a structured rerun of a symptom under controlled conditions.
- **Fields**:
  - `id` (string): Stable case identifier.
  - `symptom_id` (string): Referenced `LocalSymptom`.
  - `steps` (list[string]): Ordered reproduction steps.
  - `expected_result` (string): What must be observed if the symptom still holds.
  - `actual_result` (string): What was observed in the latest run.
  - `status` (enum): `pending | reproduced | not_reproduced`.
- **Validation rules**:
  - A case is valid only if it is non-destructive to the store.
  - Reproduction cases must avoid secret-value disclosure.

## Entity: FailureHypothesis

- **Purpose**: Represent a reasoned explanation connecting upstream evidence to one or more local symptoms.
- **Fields**:
  - `id` (string): Stable hypothesis identifier.
  - `summary` (string): One-sentence explanation.
  - `evidence_ids` (list[string]): Linked `UpstreamEvidence` records.
  - `symptom_ids` (list[string]): Linked `LocalSymptom` records.
  - `confidence` (enum): `confirmed | strong_inference | weak_inference | unresolved`.
  - `disproven_by` (list[string]): Conditions that would invalidate the hypothesis.
- **Validation rules**:
  - A confirmed hypothesis must cite at least one upstream source and one local reproduction.
  - Unresolved hypotheses must state what evidence is missing.

## Entity: OperationalDecision

- **Purpose**: Represent the final outcome of the research feature.
- **Fields**:
  - `decision` (enum): `continue_debugging | plan_migration`.
  - `acceptance_boundary` (string): Operational criterion used to judge success, explicitly including both non-interactive `gopass show` and `chezmoi apply`.
  - `stop_condition` (string): Explicit condition that ends current-backend experimentation.
  - `minimum_next_decision` (string): What the next feature must decide if migration is chosen, explicitly the target backend.
  - `residual_unknowns` (list[string]): Open questions left after research.
- **Validation rules**:
  - The decision must be explainable without requiring implementation details.
  - The stop condition must be observable and testable on the current workstation.
  - If `decision = plan_migration`, `minimum_next_decision` must not assume a backend before comparative evaluation.
