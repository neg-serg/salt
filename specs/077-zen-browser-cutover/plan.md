# Implementation Plan: Zen Browser Cutover

**Branch**: `077-zen-browser-cutover` | **Date**: 2026-03-26 | **Spec**: [spec.md](/home/neg/src/salt/specs/077-zen-browser-cutover/spec.md)
**Input**: Feature specification from `/specs/077-zen-browser-cutover/spec.md`

## Summary

Cut over the managed workstation browser path so Zen Browser becomes the primary browser for all common launch surfaces while Floorp remains a fully managed secondary browser. The design keeps the current localhost helper service, uses the existing `zen_profile`-driven Salt path as the Zen profile source of truth, preserves explicit secondary Floorp launchers, and adds an end-to-end verification flow that proves Zen Browser, Surfingkeys, and the helper work together on the target host.

## Technical Context

**Language/Version**: Jinja2 + YAML Salt states, Python 3 helper script, Markdown operator docs  
**Primary Dependencies**: Salt 3006.x masterless workflow, existing `_macros_*.jinja`, `zen-browser-bin`, Surfingkeys browser extension, systemd user services, Hyprland/Wayfire launcher config, spec-kit artifacts  
**Storage**: Repository-managed state/data files plus browser profile files under the existing Zen profile directory and user-service-managed local helper process  
**Testing**: `just` render verification, targeted repo validation, operator verification flow for browser launch surfaces, Surfingkeys extension presence, helper service health, and helper-assisted browser actions  
**Target Platform**: CachyOS/Arch-derived Linux workstation, primary host `telfir`, Hyprland and Wayfire launch environments  
**Project Type**: Configuration-management feature and operator verification design for a desktop workstation  
**Performance Goals**: Complete one apply-and-verify session in under 10 minutes; helper-assisted Surfingkeys actions should succeed on first attempt during verification  
**Constraints**: Preserve idempotent Salt behavior; keep the existing helper behavior rather than redesigning it; keep launch-entry migration limited to in-repo managed surfaces; preserve the working Zen profile binding already defined in host data; keep Floorp fully managed but never as the default/common browser target  
**Scale/Scope**: One primary host, one Zen profile binding, one Surfingkeys helper service, three known in-repo browser launch surfaces, one browser cutover workflow

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Idempotency**: Pass. The planned implementation stays inside existing Salt patterns and explicitly treats helper management and browser-profile deployment as idempotent state changes rather than ad-hoc commands.
- **II. Network Resilience**: Pass. The feature reuses the established browser-extension download pattern and does not introduce new network behavior beyond existing managed extension fetches.
- **III. Secrets Isolation**: Pass. No secret storage or plaintext secret handling is introduced.
- **IV. Macro-First**: Pass. Browser package and extension management remain within existing package/install macro patterns.
- **V. Minimal Change**: Pass. Scope is limited to browser cutover, helper parity, launch-surface migration, and verification artifacts required by the request.
- **VI. Convention Adherence**: Pass. The design stays within existing `states/`, `states/data/`, `dotfiles/`, `tests/`, and `docs/` conventions.
- **VII. Verification Gate**: Pending final local `just` verification after artifact generation.
- **VIII. CI Gate**: Pass for planning stage; later implementation remains CI-gated.

**Gate Result (Pre-Research)**: PASS

## Project Structure

### Documentation (this feature)

```text
specs/077-zen-browser-cutover/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── browser-cutover-surfaces.yaml
│   └── verification-matrix.yaml
└── tasks.md
```

### Source Code (repository root)

```text
dotfiles/
├── dot_config/hypr/bindings/apps.conf
├── dot_config/wayfire.ini
├── dot_config/wlr-which-key/config.yaml
├── dot_config/surfingkeys.js
├── dot_config/zen-browser/
└── dot_local/bin/executable_surfingkeys-server

states/
├── desktop/packages.sls
├── floorp.sls
├── zen_browser.sls
├── user_services.sls
├── units/user/surfingkeys-server.service
└── data/
    ├── floorp.yaml
    ├── hosts.yaml
    ├── user_services.yaml
    └── zen_browser.yaml

tests/
└── test_host_model.py

specs/077-zen-browser-cutover/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
```

**Structure Decision**: This feature is a Salt-and-dotfiles desktop cutover. Implementation work will span browser package/launch/profile configuration in `states/` and `dotfiles/`, with host-model assertions in `tests/`, while design and operator workflow artifacts stay under `specs/077-zen-browser-cutover/`.

## Phase 0: Research Summary

- Preserve the current Surfingkeys helper pattern as a localhost HTTP service instead of designing around browser native-messaging manifests.
- Treat `host.zen_profile` plus `zen_browser.sls` as the profile source of truth for the target browser path.
- Replace all managed in-repo common browser launch surfaces with Zen Browser launch/class matching while preserving explicit secondary Floorp launchers.
- Use the existing Zen extension manifest as the parity baseline and preserve Surfingkeys plus the helper-dependent actions wired in `surfingkeys.js`.
- Validate the cutover in layers: Salt render gate, launch-surface migration, helper service health, extension/profile presence, and runtime helper-assisted actions.

## Phase 1: Design Outputs

- `research.md`: resolved design decisions for helper architecture, launch migration, profile source of truth, verification, and Floorp secondary-browser boundary
- `data-model.md`: entities for managed browser path, launch surfaces, Zen profile binding, helper workflow, and verification run
- `contracts/browser-cutover-surfaces.yaml`: declarative contract for the in-scope launch surfaces and expected post-cutover targets
- `contracts/verification-matrix.yaml`: explicit verification coverage for render, package/profile wiring, helper service, and Surfingkeys runtime actions
- `quickstart.md`: operator sequence for apply, validate, and troubleshoot the cutover on the target host

## Post-Design Constitution Check

- **I. Idempotency**: Pass. The design stays within managed Salt state transitions and avoids bespoke one-shot runtime hacks as the primary cutover mechanism.
- **II. Network Resilience**: Pass. No new network pattern beyond existing extension fetch logic is introduced.
- **III. Secrets Isolation**: Pass. No secret-handling changes.
- **IV. Macro-First**: Pass. Package and extension management remain aligned with existing macro-driven patterns.
- **V. Minimal Change**: Pass. Artifacts remain tightly scoped to requested browser migration and verification.
- **VI. Convention Adherence**: Pass. The design uses the repository’s standard file layout and documentation approach.
- **VII. Verification Gate**: Pass after local `just` verification.
- **VIII. CI Gate**: Pass for planning stage; implementation remains CI-gated.

**Gate Result (Post-Design)**: PASS
