# Data Model: Zen Browser Cutover

## 1. Managed Browser Path

Represents the repository-managed definition of which browser is treated as the supported daily browser on the target host.

### Fields

- `host_name`: target host identifier
- `browser_package`: managed browser package/command exposed to the operator
- `profile_binding`: profile identifier that receives managed browser customizations
- `launch_surfaces`: list of in-repo entry points that raise or launch the browser
- `legacy_dependencies`: list of managed Floorp-specific dependencies still present before cutover
- `status`: `legacy`, `mixed`, or `cutover_complete`

### Validation Rules

- `browser_package` must resolve to Zen Browser after the cutover.
- `profile_binding` must reference the existing Zen profile for the target host.
- `launch_surfaces` must not contain active Floorp launch targets in `cutover_complete`.
- `status=cutover_complete` requires helper parity verification success.

### Relationships

- Owns one `Zen Profile Binding`.
- References many `Browser Launch Surface` entries.
- Depends on one `Surfingkeys Helper Workflow` definition for parity validation.

## 2. Zen Profile Binding

Represents the operator-managed binding between the target host and the Zen Browser profile directory that receives Salt-managed files and extensions.

### Fields

- `host_name`: target host identifier
- `profile_id`: configured Zen profile directory name
- `managed_files`: profile-scoped files delivered by Salt
- `managed_extensions`: extension identifiers expected in the Zen profile
- `reset_artifacts`: profile files intentionally rebuilt when extension wiring changes

### Validation Rules

- `profile_id` must be non-empty for the cutover target.
- `managed_files` must include the profile preferences file and UI customization file already defined for Zen.
- `managed_extensions` must include Surfingkeys.
- `reset_artifacts` must match the browser-profile rebuild behavior used by the Zen state.

### Relationships

- Belongs to one `Managed Browser Path`.
- Provides browser prerequisites for one `Verification Run`.

## 3. Browser Launch Surface

Represents an operator-facing managed entry point in the repository that launches or raises the browser.

### Fields

- `surface_id`: stable identifier for the launcher surface
- `file_path`: repository file containing the launch rule
- `trigger`: keybinding or launcher name
- `match_rule`: window class/app-id match used by the raise-or-launch behavior
- `launch_command`: executable or command string used to launch the browser
- `post_cutover_target`: expected Zen-specific match and command outcome

### Validation Rules

- Every in-scope launch surface must have a unique `surface_id`.
- `file_path` must resolve to a repository-managed launcher file.
- `post_cutover_target` must point to Zen Browser rather than Floorp.
- `match_rule` and `launch_command` must be updated together for raise-or-launch behavior.

### Relationships

- Belongs to one `Managed Browser Path`.
- Is covered by one or more `Verification Run` checks.

## 4. Surfingkeys Helper Workflow

Represents the helper-dependent browser actions that must continue to work after the cutover.

### Fields

- `service_name`: managed helper service name
- `helper_endpoint_base`: local helper base URL
- `supported_actions`: named Surfingkeys actions that require the helper
- `failure_signal`: user-visible symptom when helper access fails
- `window_focus_dependency`: desktop-environment behavior the helper relies on

### Validation Rules

- `service_name` must correspond to a managed user service.
- `helper_endpoint_base` must remain locally reachable on the target host during verification.
- `supported_actions` must include address-bar focus and new-tab helper flow.
- `failure_signal` must remain observable to the user when the helper is unavailable.

### Relationships

- Supports one `Managed Browser Path`.
- Is exercised by one or more `Verification Run` steps.

## 5. Verification Run

Represents one complete execution of the browser cutover validation flow on the target host.

### Fields

- `run_id`: unique verification instance identifier
- `host_name`: target host identifier
- `render_gate`: result of repository render validation
- `launch_surface_results`: per-surface pass/fail outcomes
- `profile_results`: profile and extension presence outcomes
- `service_results`: helper service health outcomes
- `runtime_action_results`: pass/fail outcomes for helper-assisted Surfingkeys actions
- `overall_status`: `pass` or `fail`
- `failure_domain`: `render`, `launch`, `profile`, `service`, `runtime_action`, or `none`

### Validation Rules

- `overall_status=pass` requires all result groups to pass.
- `failure_domain` must be `none` only when `overall_status=pass`.
- At least one runtime helper-assisted action must be recorded.
- A failed run must identify the first failing domain clearly enough for operator triage.

### Relationships

- Validates one `Managed Browser Path`.
- Reads prerequisites from one `Zen Profile Binding`.
- Exercises one `Surfingkeys Helper Workflow`.
