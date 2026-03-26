# Phase 0 Research: Zen Browser Cutover

## Decision 1: Keep the existing Surfingkeys helper architecture and treat it as a localhost HTTP service

- **Decision**: Preserve the current helper pattern as the user service `surfingkeys-server.service` serving `http://localhost:18888`, with Surfingkeys actions continuing to call `/focus` and `blank.html`.
- **Rationale**: The repository already shows that the working Floorp workflow is not based on browser native-messaging manifests. `dotfiles/dot_local/bin/executable_surfingkeys-server` serves HTTP from `~/.config`, and `dotfiles/dot_config/surfingkeys.js` calls `fetch('http://localhost:18888/focus')` and opens `http://localhost:18888/blank.html`. Reusing that pattern avoids solving the wrong problem.
- **Alternatives considered**:
  - Introduce a browser native-messaging manifest flow: rejected because it does not match the current implementation and would expand scope into a parallel helper design.
  - Remove the helper and depend only on default Surfingkeys behavior: rejected because the requested parity specifically includes the helper-assisted actions.

## Decision 2: Use the existing Zen profile binding as the browser-profile source of truth

- **Decision**: Treat `host.zen_profile` in `states/data/hosts.yaml` plus `states/zen_browser.sls` as the supported browser-profile path for the cutover target.
- **Rationale**: The target host already has both `floorp_profile` and `zen_profile` defined. Zen-specific `user.js`, `userChrome.css`, and extension deployment already exist in the repository and are gated on `host.zen_profile`.
- **Alternatives considered**:
  - Auto-discover Zen profiles dynamically as part of this feature: rejected because the repository already stores an explicit profile binding and no new discovery problem needs to be introduced.
  - Keep Floorp as the profile source of truth and mirror into Zen: rejected because it preserves dual-browser drift and undermines the cutover.

## Decision 3: Migrate all in-repo managed browser launch surfaces together

- **Decision**: Treat browser launcher migration as a first-class cutover track covering every managed surface in the repository that still raises or launches Floorp.
- **Rationale**: The repository currently hard-codes Floorp launch behavior in `dotfiles/dot_config/hypr/bindings/apps.conf`, `dotfiles/dot_config/wayfire.ini`, and `dotfiles/dot_config/wlr-which-key/config.yaml`. If those stay untouched, the operator still reaches the old browser even after package/profile work is complete.
- **Alternatives considered**:
  - Change only the Salt browser state and leave launchers for later: rejected because it creates an incomplete cutover with contradictory operator entry points.
  - Replace only the launch command but keep Floorp window matching: rejected because raise-or-launch flows depend on the correct window class as well as the executable.

## Decision 4: Use the installed Zen desktop metadata as the launch contract

- **Decision**: Base the launch target on the installed Zen desktop metadata: executable `/usr/bin/zen-browser` backed by `/opt/zen-browser-bin/zen-bin %u`, and window class `zen`.
- **Rationale**: The local system already exposes `/usr/bin/zen-browser`, and `/usr/share/applications/zen.desktop` declares `StartupWMClass=zen`. That is the strongest local source for updating Hyprland and Wayfire raise-or-launch rules without guessing.
- **Alternatives considered**:
  - Preserve `floorp` command aliases and rely on user shell indirection: rejected because managed launchers should describe the real managed browser target.
  - Leave the runtime class to be discovered during implementation: rejected because this question is answerable now from the installed package metadata.

## Decision 5: Keep Zen extension parity anchored to the existing Zen extension manifest

- **Decision**: Use `states/data/zen_browser.yaml` as the baseline extension contract for Zen Browser, preserving Surfingkeys and the existing shared Firefox-compatible extensions while not reintroducing Floorp-only theme extensions.
- **Rationale**: The repository already maintains a dedicated Zen extension manifest that includes Surfingkeys and deliberately excludes Floorp-specific items such as adaptive tab bar color and a Floorp-only theme. That is the right parity boundary for a cutover whose goal is functional workflow preservation, not pixel-identical browser theming.
- **Alternatives considered**:
  - Clone the Floorp extension list wholesale into Zen: rejected because the repo already marks some items as Floorp-specific and unsuitable for Zen.
  - Reduce Zen to only Surfingkeys: rejected because the cutover is for the managed daily browser path, not a minimal test browser.

## Decision 6: Keep Floorp fully managed, but demote it to explicit secondary launch paths

- **Decision**: Keep Floorp package/config management in place, but make Zen Browser the common/default browser target while moving Floorp behind explicit secondary launch paths.
- **Rationale**: Clarification established that both browsers remain fully managed. The cutover still needs one clear primary browser target for daily entry points, so the implementation should demote Floorp from shared launchers without removing its managed package/profile path.
- **Alternatives considered**:
  - Delete every Floorp-related file in one pass: rejected because the clarified scope keeps Floorp fully managed.
  - Keep both browser paths equally mapped on common launchers: rejected because it preserves ambiguity in operator-facing defaults.

## Decision 7: Use a layered verification flow that proves both configuration and runtime behavior

- **Decision**: Verify the feature in five layers: render gate, host-model/browser wiring checks, launcher target checks, helper service health, and runtime Surfingkeys actions inside Zen Browser.
- **Rationale**: The request explicitly asks to “trace through the repository how it works and test that everything works.” That requires both static confirmation that the repository points at Zen and runtime confirmation that the helper-assisted actions still succeed.
- **Alternatives considered**:
  - Limit verification to `just`: rejected because render success does not prove the runtime browser/helper path works.
  - Rely only on manual browser clicking: rejected because it would not prove the repository wiring and would be hard to repeat.

## Clarifications Resolved

- **Helper technology**: The existing “native server” is a localhost HTTP helper, not a browser native-messaging manifest integration.
- **Target browser profile**: The cutover should use the already-defined `zen_profile` for the target host.
- **Launch target**: In-repo browser launcher surfaces should target Zen Browser with runtime class `zen`.
- **Extension boundary**: Zen keeps its dedicated extension manifest, including Surfingkeys and other shared extensions, without reintroducing Floorp-only items.
- **Floorp boundary**: Floorp remains fully managed, but only explicit secondary launchers should open it by default after the cutover.
