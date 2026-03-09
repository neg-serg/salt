# Feature Specification: Chezmoi/Salt File Ownership Boundary

**Feature Branch**: `007-chezmoi-salt-boundary`
**Created**: 2026-03-09
**Status**: Draft
**Input**: User description: "надо посмотреть как добиться того чтобы не было двух владельцев у файлов(chezmoi vs salt)"

## Clarifications

### Session 2026-03-09

- Q: Who should own the proxypilot config — Salt (Jinja2, gopass fallback) or chezmoi (Go template, hard-fails without gopass)? → A: Salt owns it (robust fallback, service-critical).
- Q: What happens to the "losing" tool's source files when ownership moves? → A: Hybrid cleanup — delete Salt state lines for chezmoi-owned files; for Salt-owned files, use `.chezmoiignore` if Salt sources from `dotfiles/`, or delete chezmoi template if Salt has a separate source.
- Q: How to prevent future dual-write regressions — documentation only, lint script, or `.chezmoiignore` as inventory? → A: Documentation in CLAUDE.md + automated lint script that checks for path overlaps (runs as part of `just`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Eliminate Dual-Write File Conflicts (Priority: P1)

As the system administrator, I want each configuration file to have exactly one owner (either chezmoi or Salt, never both), so that applying either tool never overwrites or conflicts with the other's output.

**Why this priority**: Dual-write is the root cause of all ownership ambiguity. Eight files are currently deployed by both tools, creating race conditions, permission divergence, and wasted apply cycles. Fixing this eliminates the entire class of problems.

**Independent Test**: After applying the change, run `salt-call state.apply` followed by `chezmoi apply` — no file should be written by both tools. Verify by checking that Salt states no longer reference paths owned by chezmoi and vice versa.

**Acceptance Scenarios**:

1. **Given** the 8 currently dual-written files (mpd.conf, floorp user.js, floorp chrome CSS files, mpdas.service, proxypilot config), **When** Salt apply runs, **Then** Salt only manages files it is designated to own and skips the rest.
2. **Given** chezmoi source directory, **When** `chezmoi apply` runs, **Then** chezmoi only manages files it is designated to own and does not touch Salt-owned files.
3. **Given** a fresh system where neither tool has run, **When** Salt apply runs first and then chezmoi apply runs, **Then** all 8 previously-conflicting files are deployed exactly once by their designated owner.

---

### User Story 2 - Establish Ownership Decision Policy (Priority: P2)

As a contributor to this project, I want a clear, documented policy that determines which tool should own any given configuration file, so that future additions follow the same pattern without re-introducing dual-write.

**Why this priority**: Without a policy, the dual-write problem will recur every time a new config file is added. A documented decision framework prevents regression.

**Independent Test**: A new contributor can read the policy document and correctly determine which tool should own a hypothetical new config file (e.g., a new application config that requires secret injection vs. a purely declarative theme file).

**Acceptance Scenarios**:

1. **Given** a configuration file that requires secret injection at deploy time, **When** consulting the ownership policy, **Then** the policy clearly assigns it to Salt.
2. **Given** a configuration file that is purely declarative (no secrets, no service triggers), **When** consulting the ownership policy, **Then** the policy clearly assigns it to chezmoi.
3. **Given** a configuration file that triggers a service restart on change, **When** consulting the ownership policy, **Then** the policy explains whether Salt or chezmoi should own it based on the trigger mechanism.

---

### User Story 3 - Verify No Regressions After Ownership Migration (Priority: P3)

As the system administrator, I want the migration to single ownership to be safe and reversible, so that no configuration is lost or broken during the transition.

**Why this priority**: The migration itself is a risk — moving ownership could cause files to be missing on the next apply if done incorrectly. A verification step ensures nothing breaks.

**Independent Test**: Run `salt-call state.apply` and `chezmoi apply` on a system with existing dual-written files. All 8 files should have correct content, correct permissions, and correct ownership after the migration.

**Acceptance Scenarios**:

1. **Given** a system with all 8 dual-written files in place, **When** ownership migration is applied, **Then** all files retain their current content and permissions.
2. **Given** the migration has been applied, **When** `salt-call state.apply` runs, **Then** it reports 0 failures and does not attempt to manage files now owned by chezmoi.
3. **Given** the migration has been applied, **When** `chezmoi apply` runs, **Then** it does not attempt to manage files now owned by Salt.

---

### Edge Cases

- What happens if Salt apply runs but chezmoi has not yet applied (fresh install)? Files owned by chezmoi should not exist until chezmoi runs — Salt must not create them as a side-effect.
- What happens if a file needs secrets AND triggers a service restart? The ownership policy must have a clear tiebreaker (Salt wins, since it handles both secrets and service lifecycle).
- What happens if chezmoi is temporarily unavailable (broken gopass, missing GPG key)? Salt-owned files must still deploy correctly. Chezmoi-owned files are expected to fail gracefully (chezmoi's own error handling).
- What happens to the proxypilot config that currently has two different template sources (Salt's Jinja2 vs chezmoi's Go templates)? Salt owns this file — its Jinja2 template with gopass fallback is the single source; the chezmoi Go template must be removed or excluded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each configuration file in the project MUST have exactly one designated owner: either Salt or chezmoi, never both.
- **FR-002**: Salt MUST NOT deploy `file.managed`/`file.recurse` states for files designated as chezmoi-owned. The corresponding Salt state lines MUST be deleted (not commented out).
- **FR-003**: Chezmoi MUST NOT deploy files designated as Salt-owned. If Salt sources the file from `dotfiles/` (`salt://dotfiles/...`), the file MUST remain in `dotfiles/` and be excluded via `.chezmoiignore`. If Salt has a separate source (e.g., `salt://configs/...`), the chezmoi template MUST be deleted entirely.
- **FR-004**: Salt MUST own files that require any of: (a) secret injection via gopass with fallback, (b) service restart triggers via `watch`/`onchanges`, (c) conditional deployment based on Salt grains/pillar.
- **FR-005**: Chezmoi MUST own files that are purely declarative user dotfiles with no service lifecycle dependencies.
- **FR-006**: The ownership policy MUST be documented in the project's CLAUDE.md conventions section, so that both human contributors and AI agents follow it.
- **FR-007**: The proxypilot configuration (`~/.config/proxypilot/config.yaml`) MUST be owned by Salt using its Jinja2 template with gopass fallback. The chezmoi Go template (`config.yaml.tmpl`) MUST be removed or excluded via `.chezmoiignore`.
- **FR-008**: The migration MUST preserve existing file content and permissions for all 8 affected files during the transition.
- **FR-009**: A lint script MUST detect path overlaps between Salt states (`file.managed`/`file.recurse` sources) and chezmoi source directory, and MUST run as part of the `just` default workflow to catch regressions before they reach the system.

### Key Entities

- **Owned File**: A configuration file with a single designated management tool (Salt or chezmoi), a deploy path, and ownership rationale.
- **Ownership Policy**: A set of decision rules that map file characteristics (secrets, triggers, declarative) to the appropriate management tool.
- **Dual-Write Conflict**: A file currently managed by both tools, identified by path overlap between Salt states and chezmoi source directory.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero files are deployed by both Salt and chezmoi — verifiable by auditing Salt states and chezmoi source for path overlaps.
- **SC-002**: Salt apply (`salt-call state.apply`) completes with 0 failures after ownership migration.
- **SC-003**: Chezmoi apply (`chezmoi apply`) completes with 0 errors after ownership migration.
- **SC-004**: The ownership policy document covers 100% of currently dual-written files with explicit owner assignments.
- **SC-005**: A new contributor can determine file ownership for any config file within 1 minute by consulting the policy.
- **SC-006**: The lint script detects any newly introduced dual-write overlap and fails the `just` workflow, preventing regressions from being applied.

## Assumptions

- The symlink bridge (`~/.local/share/chezmoi → ~/src/salt/dotfiles`) will remain in place — both tools share the same source tree.
- Salt always runs before chezmoi in the standard apply workflow (Salt sets up the symlink bridge that chezmoi depends on).
- The 8 dual-written files identified in the audit report (docs/audit-report.md, finding F10) represent the complete set of current overlaps.
- Files that Salt deploys with `replace: False` (seed-only) are not considered dual-write conflicts if chezmoi does not also manage them.
- System-level paths (`/etc/`, `/boot/`, `/usr/`) are exclusively Salt-owned and are not in scope for this feature (no overlap exists there).

## Constraints

- No new tools or dependencies should be introduced — the solution uses existing Salt and chezmoi mechanisms (`.chezmoiignore`, state removal, documentation) plus a new lint script using only standard tools already available in the project.
- The migration must be backward-compatible: a partial apply (only Salt, or only chezmoi) must not leave the system in a broken state.
- Secret handling strategy differences (Salt's gopass+fallback vs chezmoi's gopass-only) must be considered when assigning ownership of secret-containing files.
