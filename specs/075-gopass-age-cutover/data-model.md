# Data Model: Gopass Age Cutover

## Entity: ActiveStoreState

- **Purpose**: Represent the currently authoritative encrypted secret store during baseline, cutover, rollback, and stabilization.
- **Fields**:
  - `backend` (enum): `legacy_gpg | age`.
  - `store_path` (string): Filesystem path to the active `gopass` store.
  - `path_marker` (enum): `.gpg-id | .age-recipients`.
  - `session_status` (enum): `locked | unlocked | mixed | unknown`.
  - `source_of_truth` (boolean): Whether this state is the only active store in use.
- **Validation rules**:
  - Exactly one store state may be marked as the active source of truth at any time.
  - A successful cutover changes the backend marker without changing secret paths.

## Entity: SecretConsumer

- **Purpose**: Represent one workflow or artifact that reads secrets from the active store.
- **Fields**:
  - `id` (string): Stable identifier such as `chezmoi-msmtp` or `salt-proxypilot`.
  - `category` (enum): `cli | chezmoi_template | salt_state | shell_script | repo_validation`.
  - `path` (string): Repository or operational path that consumes the secret.
  - `secret_paths` (list[string]): `gopass` entries the consumer depends on.
  - `priority` (enum): `high | medium | low`.
  - `validation_method` (string): Observable check proving the consumer still works.
- **Relationships**:
  - Participates in one or more `ValidationCase` records.

## Entity: ValidationCase

- **Purpose**: Represent one concrete proof that the migrated store still behaves correctly.
- **Fields**:
  - `id` (string): Stable validation identifier.
  - `consumer_id` (string): Reference to the associated `SecretConsumer`.
  - `kind` (enum): `secret_read | template_render | apply_check | state_validation | repo_validation | special_entry_check | rollback_check`.
  - `input_reference` (string): Secret path, file path, or workflow trigger.
  - `expected_result` (string): Observable success condition.
  - `must_match_baseline` (boolean): Whether the result must be identical to baseline.
  - `execution_stage` (list[enum]): `baseline | cutover | rollback | stabilization`.
  - `status` (enum): `pending | passed | failed`.
- **Validation rules**:
  - High-priority consumers must have at least one baseline and one cutover case.
  - Rollback acceptance must reuse representative cases from the forward path.

## Entity: RollbackPackage

- **Purpose**: Capture the recovery artifacts and written steps required to restore the last known-good state.
- **Fields**:
  - `store_backup` (string): Backup location for the active store contents.
  - `history_backup` (string): Backup location for associated git history.
  - `legacy_unlock_material` (list[string]): Required legacy unlock artifacts retained for recovery.
  - `rollback_steps` (list[string]): Ordered steps to reactivate the previous working store.
  - `verification_cases` (list[string]): Validation cases that prove rollback succeeded.
  - `retention_window` (string): Minimum period the rollback package must be preserved.
- **Validation rules**:
  - The package is invalid if any rollback step depends on missing artifacts.
  - Live conversion is blocked until the full package exists.

## Entity: UnlockArtifact

- **Purpose**: Represent the materials and procedures required for the `age` backend to work in daily use and recovery.
- **Fields**:
  - `artifact_type` (enum): `identity_file | password | recovery_note | session_unlock_step`.
  - `storage_location` (string): Where the artifact or instruction is kept.
  - `protection_method` (string): How the artifact is protected at rest.
  - `recovery_usage` (string): How the artifact is used on a new machine or in a new session.
- **Validation rules**:
  - Unlock artifacts must support both same-session usage and later recovery.
  - Recovery usage must be documented before legacy retirement.

## Entity: SpecialEntrySubset

- **Purpose**: Track the representative subset of attached files, unusual names, or non-password records that remain inside migration scope.
- **Fields**:
  - `selection_reason` (string): Why the subset is representative.
  - `entries` (list[string]): Selected paths or records.
  - `baseline_observation` (string): What was confirmed before cutover.
  - `post_cutover_observation` (string): What was confirmed after cutover.
- **Validation rules**:
  - The subset must include at least one non-standard store record when such records exist.
  - The same subset must be reused for rollback validation.

## Entity: StabilizationWindow

- **Purpose**: Define the observation period between successful cutover acceptance and legacy-path retirement.
- **Fields**:
  - `start_condition` (string): Event that starts the window.
  - `duration_rule` (string): Fixed to 7 consecutive days after successful cutover validation.
  - `required_workflows` (list[string]): Workflows that must succeed during the window.
  - `fallback_allowed` (boolean): Whether the old path may still exist during stabilization.
  - `retirement_condition` (string): Condition that permits legacy retirement.
  - `failure_triggers` (list[string]): Events that block retirement or force rollback review.
- **Validation rules**:
  - Legacy access may remain available during stabilization, but any fallback use blocks retirement.
  - Stabilization exits only after 7 consecutive days with no fallback and no unresolved required-workflow failures.
