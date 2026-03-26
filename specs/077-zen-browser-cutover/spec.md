# Feature Specification: Zen Browser Cutover

**Feature Branch**: `077-zen-browser-cutover`  
**Created**: 2026-03-26  
**Status**: Draft  
**Input**: User description: "Мне надо чтобы ты перевел меня на использование zen-browser вместо floorp. Но для этого необходимо чтобы там заработал тот же native server который у меня уже сделан для surfingkeys из настройки floorp и можно проследить по этому репозиторию как это работает и протестировать что все работает"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use Zen Browser as the primary daily browser (Priority: P1)

As the workstation operator, I want my managed browser setup to switch from Floorp to Zen Browser so that my everyday browsing environment uses one supported browser path instead of maintaining two overlapping Firefox-derived setups.

**Why this priority**: The cutover has no value unless Zen becomes the browser that the managed workstation can rely on for day-to-day use.

**Independent Test**: Apply the managed workstation configuration on the primary host, launch Zen Browser from the normal desktop entry points, and confirm that the expected browser profile settings and extension set are present without depending on Floorp.

**Acceptance Scenarios**:

1. **Given** the workstation has both historical Floorp settings and an existing Zen profile, **When** the operator applies the managed browser configuration, **Then** Zen Browser becomes the supported browser path for the managed workstation experience.
2. **Given** the operator launches the browser through the normal package, launcher, or window-manager entry points, **When** Zen Browser starts after the cutover, **Then** it opens with the managed profile customizations and required browsing extensions already available.

---

### User Story 2 - Keep Surfingkeys browser-assisted actions working in Zen (Priority: P1)

As a Surfingkeys user, I want the same browser-assisted actions that currently work with the Floorp setup to work in Zen Browser so that I do not lose critical keyboard-driven browsing behavior during the migration.

**Why this priority**: The native helper path is the main operational constraint in the request. If those actions stop working, the migration is a regression even if Zen launches successfully.

**Independent Test**: Start the managed helper service, open Zen Browser with Surfingkeys enabled, trigger the existing actions that rely on the local helper, and confirm they succeed without browser-specific workarounds.

**Acceptance Scenarios**:

1. **Given** the local Surfingkeys helper is running, **When** the user triggers the existing address-bar focus action from Surfingkeys inside Zen Browser, **Then** the browser performs the same helper-assisted focus behavior that the current Floorp workflow provides.
2. **Given** the local Surfingkeys helper is running, **When** the user triggers the existing new-tab action that depends on the local helper path, **Then** the new tab opens and the expected follow-up focus behavior completes successfully inside Zen Browser.
3. **Given** the helper is unavailable or disconnected, **When** the user triggers one of those helper-assisted Surfingkeys actions in Zen Browser, **Then** the failure is visible to the user and does not silently degrade into an ambiguous state.

---

### User Story 3 - Verify the Zen workflow without breaking dual-browser management (Priority: P2)

As the operator, I want an explicit validation workflow for the browser cutover so that I can prove Zen Browser, Surfingkeys, and the local helper work together while keeping Floorp available as a separately managed browser without making Floorp helper-parity part of this feature's acceptance boundary.

**Why this priority**: Browser migration without a repeatable validation path invites false positives and leaves hidden regressions in profile wiring, extensions, or service startup.

**Independent Test**: Follow the documented verification workflow on the target host and confirm that each required browser capability and helper-assisted action passes in one session.

**Acceptance Scenarios**:

1. **Given** the cutover changes have been applied, **When** the operator runs the defined verification flow, **Then** the result clearly shows whether Zen Browser, Surfingkeys, and the helper path are all functioning together.
2. **Given** one part of the cutover is missing or miswired, **When** the operator runs the verification flow, **Then** the failure points to the broken browser, profile, extension, or helper dependency instead of forcing guesswork.

### Edge Cases

- What happens if the Zen profile exists but is missing one or more managed browser customizations at cutover time?
- What happens if Surfingkeys is present in Zen Browser but helper-assisted actions fail because the local helper service is not active?
- What happens if the managed workstation still contains Floorp-specific browser settings that are not meaningful for Zen Browser?
- What happens if Zen Browser launches correctly but the user reaches it through an old desktop or window-manager command path that still targets Floorp?
- What happens if the extension set differs between the old Floorp path and the target Zen path in a way that blocks the expected Surfingkeys workflow?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST define Zen Browser as the primary managed browser path for the workstation targeted by this cutover while keeping Floorp as a separately supported managed browser.
- **FR-002**: The system MUST apply the managed browser profile inputs required for the existing Zen Browser setup on the target host.
- **FR-003**: The system MUST carry forward the existing Surfingkeys experience required for daily browsing, including the actions that currently depend on the local browser helper path.
- **FR-004**: The system MUST preserve in Zen Browser the helper-assisted Surfingkeys behaviors that the current Floorp workflow already provides, rather than replacing them with a reduced manual workflow.
- **FR-005**: The system MUST ensure Zen Browser receives the required Surfingkeys extension presence and profile wiring needed for those helper-assisted actions to operate.
- **FR-006**: The system MUST keep the local Surfingkeys helper available as a managed user-level capability during and after the browser cutover.
- **FR-007**: The system MUST map all common operator-facing browser launch surfaces to Zen Browser after the cutover while leaving Floorp available only through separate explicit launcher paths.
- **FR-008**: The system MUST preserve in-scope Floorp-specific managed dependencies that are still required to keep Floorp fully managed and supported as a secondary browser path.
- **FR-009**: The system MUST provide a repeatable verification workflow that demonstrates the browser cutover end to end on the target host.
- **FR-010**: The system MUST make verification failures diagnosable by distinguishing browser launch issues, profile wiring issues, extension availability issues, and helper-service issues.
- **FR-011**: The system MUST preserve idempotent workstation management behavior so that reapplying the managed configuration after the cutover does not reintroduce Floorp dependence or require manual browser repair.

### Key Entities *(include if feature involves data)*

- **Managed Browser Path**: The set of package, profile, launch-entry, and configuration expectations that define which browser the workstation treats as supported.
- **Zen Browser Profile Binding**: The operator-managed association between the target host and the Zen profile that receives managed customizations and extensions.
- **Surfingkeys Helper Workflow**: The user-visible browser actions that rely on the local helper path and must behave the same after the cutover as they do before it.
- **Cutover Verification Flow**: The explicit sequence of checks used to prove the browser, extension, and helper path work together on the target host.
- **Floorp Legacy Dependency**: Any managed package, profile reference, launch command, or configuration path that exists only to support the old browser workflow.

## Clarifications

### Session 2026-03-26

- Q: Should the cutover fully remove Floorp from the managed browser path, keep it only as a fallback, or keep both browsers fully managed? → A: Keep both browsers fully managed and supported.
- Q: Should all common browser launch surfaces move to Zen Browser, while Floorp remains available only through a separate explicit launcher path? → A: Yes, all common browser launch surfaces should move to Zen Browser while Floorp remains separately launchable.
- Q: Should helper-assisted Surfingkeys parity be guaranteed only in Zen Browser, or in both Zen Browser and Floorp? → A: Guarantee helper-assisted Surfingkeys parity only in Zen Browser.

## Assumptions

- The target workstation already has a known Zen Browser profile that can be treated as the managed destination for this cutover.
- The current repository contains enough information about the existing Floorp and Surfingkeys workflow to trace the required helper-dependent behavior without reverse-engineering from outside the repo.
- The operator wants functional parity for the current helper-assisted Surfingkeys workflow, not a redesign of Surfingkeys behavior.
- The first successful cutover is measured on the primary host already represented in the repository before any broader multi-host rollout is considered.
- Floorp remains a fully managed secondary browser path after this feature rather than being removed from package, state, or launcher management.
- Common daily-use browser hotkeys and menu entry points should prefer Zen Browser, while Floorp should require an intentionally separate launch path.
- This feature's acceptance boundary requires helper-assisted Surfingkeys parity only for Zen Browser, not for the retained secondary Floorp path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After applying the cutover, 100% of browser launch entry points designated for Zen Browser on the target workstation open Zen Browser instead of accidentally opening Floorp.
- **SC-002**: The operator can complete the end-to-end verification flow for Zen Browser, Surfingkeys, and the local helper in 10 minutes or less on the target host.
- **SC-003**: 100% of helper-assisted Surfingkeys actions included in the verification flow succeed in Zen Browser on the target host; Floorp is out of scope for helper-parity acceptance in this feature.
- **SC-004**: Reapplying the managed workstation configuration after the cutover completes without requiring manual browser profile repair or manual helper-service recovery.
- **SC-005**: If any required part of the cutover is broken, the verification flow identifies the failure domain clearly enough that the operator can tell whether the problem is browser launch, browser profile wiring, extension presence, or helper availability.
