# Quickstart: Zen Browser Cutover

## Goal

Apply the managed browser cutover on the target host and verify that Zen Browser becomes the primary managed browser path, Floorp remains explicitly available as a secondary browser, and the Surfingkeys helper-assisted workflow continues to work in Zen Browser.

## Prerequisites

1. Work on branch `077-zen-browser-cutover`.
2. Target host has both the current host data entry and the existing Zen profile binding.
3. Zen Browser is installed through the managed package set.
4. The user-level helper service for Surfingkeys is available on the host.

## Phase 1: Static validation

1. Run `just` from the repository root and confirm Salt renders cleanly.
2. Review the target host browser bindings in:
   - `states/data/hosts.yaml`
   - `states/system_description.sls`
   - `states/zen_browser.sls`
   - `states/floorp.sls`
3. Review browser launch surfaces in:
   - `dotfiles/dot_config/hypr/bindings/apps.conf`
   - `dotfiles/dot_config/wayfire.ini`
   - `dotfiles/dot_config/wlr-which-key/config.yaml`

## Phase 2: Apply and service checks

1. Apply the repository workflow on the target host using the normal Salt operator path.
2. Confirm the Surfingkeys helper service is enabled and running for the user session.
3. Confirm the Zen profile path contains the managed profile files and Surfingkeys extension payload.
4. Confirm in-scope managed launch surfaces now point to Zen Browser by default and still expose an explicit secondary launch path for Floorp.

## Phase 3: Runtime verification

1. Start Zen Browser from each managed launcher surface in scope.
2. Confirm the existing Zen profile customizations are present.
3. Confirm Surfingkeys loads in Zen Browser.
4. Trigger the helper-assisted address-bar focus action and confirm it succeeds.
5. Trigger the helper-assisted new-tab action and confirm it opens the helper-backed page and focuses the address bar.
6. Trigger each explicit secondary Floorp launch path and confirm it still opens Floorp without being part of helper-parity acceptance.

## Failure triage

- If `just` fails: treat the issue as a render/configuration regression before runtime testing.
- If common launchers still open Floorp: treat the issue as a launch-surface migration failure.
- If explicit secondary Floorp launchers are missing: treat the issue as a secondary-browser path regression.
- If Zen starts without expected customization or Surfingkeys: treat the issue as a profile/extension wiring failure.
- If Surfingkeys actions fail with helper-related banner/error behavior: treat the issue as a helper service or endpoint failure.
- If helper endpoints respond but browser behavior is wrong: treat the issue as a runtime integration mismatch between Zen, Surfingkeys, and the desktop focus shortcut path.

## Acceptance

The cutover is accepted when:

1. `just` passes.
2. All in-scope common launch surfaces open or raise Zen Browser.
3. The helper service is active.
4. Surfingkeys is available in Zen Browser.
5. Both helper-assisted actions succeed during the same verification session.
6. Explicit secondary Floorp launch paths remain available.
