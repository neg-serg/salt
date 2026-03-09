# Data Model: Salt Code Quality Improvement

**Branch**: `009-salt-code-quality` | **Date**: 2026-03-09

## Entities

### Lint Rule

Represents a single code quality check in the lint script.

| Attribute | Description |
|-----------|-------------|
| rule_id | Unique identifier (e.g., `idempotency`, `network-retry`, `network-parallel`, `naming`) |
| severity | `error` (blocks CI) or `warning` (informational) |
| check_function | Python function that implements the check |
| suppression_key | Comment token for inline suppression (`# salt-lint: disable=<rule_id>`) |
| scope | What the rule inspects: `rendered` (parsed YAML) or `source` (raw .sls text) |

**Rules**:
- `rule_id` must be unique across all checks
- Suppression comments apply to the entire state block containing them
- Severity `error` causes non-zero exit code; `warning` does not

### Lint Suppression

Represents an inline override that disables a specific rule for a state.

| Attribute | Description |
|-----------|-------------|
| file_path | Source .sls file containing the suppression |
| line_number | Line where the suppression comment appears |
| rule_id | Which rule is suppressed |
| state_id | State ID the suppression applies to (derived from context) |

**Rules**:
- Format: `# salt-lint: disable=<rule_id>` on the line preceding or within the state block
- Multiple rules: `# salt-lint: disable=idempotency,network-retry`
- Suppression without matching violation generates a warning (stale suppression)

### Data File Schema (extended)

Existing `data/*.yaml` files gain optional new sections.

#### `data/desktop.yaml` (new)

```yaml
hyprland_ecosystem:
  - hyprpaper
  - hypridle
  - hyprlock
  - hyprpicker
  - ...
```

Consumed by `desktop.sls` via `import_yaml`.

### Macro Parameter Extensions

#### `npm_pkg` — new `version` parameter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| version | string | `''` | When set, uses version stamp instead of `creates:` guard |

#### `paru_install` — new `version` parameter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| version | string | `''` | When set, uses version stamp for idempotency |

#### `user_service_with_unit` — new macro

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| name | string | required | State ID base |
| filename | string | required | Systemd unit filename |
| source | string | `salt://units/user/{{ filename }}` | Unit file source |
| services | list | `[filename]` | Units to enable |
| start_now | list | `[]` | Units to `enable --now` |
| requires | list | `[]` | Additional requisites |
| user | string | `_user` | Service owner |
| home | string | `_home` | User home |

## State Transitions

### Lint Check Lifecycle

```
Source Files → [Parse Jinja] → Rendered YAML → [Check Rules] → Results
                                                      ↓
                                              Suppressions applied
                                                      ↓
                                              Errors / Warnings
```

No persistent state transitions — lint is a pure function from source files to diagnostics.

## Relationships

```
State File (1) ──contains──> (*) State Block
State Block (1) ──may have──> (0..1) Idempotency Guard
State Block (1) ──may have──> (0..1) Retry Config
State Block (1) ──may have──> (0..1) Parallel Flag
State Block (1) ──may have──> (*) Requisites
State Block (1) ──may have──> (0..*) Lint Suppressions

Macro (1) ──generates──> (1..*) State Blocks
Data File (1) ──consumed by──> (1..*) State Files
Lint Rule (1) ──validates──> (*) State Blocks
```
