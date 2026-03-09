# Research: Chezmoi/Salt File Ownership Boundary

**Branch**: `007-chezmoi-salt-boundary` | **Date**: 2026-03-09

## R1: Current State of 8 Dual-Written Files

### Decision
All 8 files are assigned to Salt ownership. 3 are already resolved (in `.chezmoiignore`), 5 need `.chezmoiignore` entries added, and 1 chezmoi template needs deletion.

### Rationale

**Already resolved (3 files):**

| File | Salt Source | `.chezmoiignore` | Why Salt |
|------|-----------|-------------------|----------|
| `mpd.conf` | `salt://dotfiles/dot_config/mpd/mpd.conf` | YES | `require` chain to `mpd_enabled` service |
| `mpdas.service` | `salt://dotfiles/dot_config/systemd/user/mpdas.service` | YES | `user_service_file` macro manages lifecycle |
| `proxypilot/config.yaml` | `salt://configs/proxypilot.yaml.j2` (separate) | YES | Jinja template with gopass fallback for secrets |

**Needs resolution (5 floorp files):**

| File | Salt Source | `.chezmoiignore` | Why Salt |
|------|-----------|-------------------|----------|
| `user.js` | `salt://dotfiles/dot_config/floorp/user.js` | NO | `onchanges` trigger for `floorp_reset_extensions_json` |
| `userChrome.css` | `salt://dotfiles/dot_config/floorp/userChrome.css` | NO | Deployed to profile dir `~/.floorp/<profile>/chrome/` |
| `userContent.css` | `salt://dotfiles/dot_config/floorp/userContent.css` | NO | Same profile dir target |
| `custom/userChrome.css` | `salt://dotfiles/dot_config/floorp/custom/userChrome.css` | NO | Same profile dir target |
| `custom/userContent.css` | `salt://dotfiles/dot_config/floorp/custom/userContent.css` | NO | Same profile dir target |

### Key Finding: Floorp Wrong-Target Problem

Chezmoi would deploy floorp files to `~/.config/floorp/` (standard XDG). Floorp browser actually reads from `~/.floorp/<profile>/`. Only Salt knows the correct profile path (from `host.floorp_profile` grain in `host_config.jinja`). Chezmoi's deployment is to a path Floorp never reads — not just redundant, but incorrect.

### Alternatives Considered
- **Split floorp ownership** (CSS → chezmoi, user.js → Salt): Rejected. Chezmoi cannot deploy to `~/.floorp/<profile>/` — it would need a custom target path. Also requires refactoring the Salt Jinja loop.
- **Move all to chezmoi**: Rejected. Chezmoi cannot resolve `host.floorp_profile` grain or trigger `extensions.json` reset via `onchanges`.

## R2: Proxypilot Dual-Source Resolution

### Decision
Delete `dotfiles/dot_config/proxypilot/config.yaml.tmpl` entirely (and its parent directory). Salt's Jinja2 template at `states/configs/proxypilot.yaml.j2` is the single source.

### Rationale
- Salt template uses `gopass_secret()` macro with AWK fallback — works without gopass
- Chezmoi template uses `{{ gopass "..." }}` — hard-fails without gopass
- Salt template injects `api_key`, `mgmt_key`, `free_providers` via Jinja context
- The two templates are completely independent files using different template engines
- No shared content that would be lost

### Alternatives Considered
- **Keep chezmoi template, add to `.chezmoiignore`**: Rejected. Already in `.chezmoiignore`, but leaving a dead template is confusing. Per clarification: "delete entirely when Salt has separate source."

## R3: Lint Script Approach

### Decision
New Python lint script (`scripts/lint-ownership.py`) that detects `salt://dotfiles/` references in `.sls` files and cross-checks against `.chezmoiignore` to find unexcluded paths.

### Rationale
- Existing lint scripts follow the same pattern: Python script in `scripts/`, invoked by `just lint`
- The script parses `salt://dotfiles/` URIs from `.sls` files, converts to chezmoi-relative paths, and verifies each is listed in `.chezmoiignore`
- Any `salt://dotfiles/` path NOT in `.chezmoiignore` is a dual-write violation
- Catches regressions when new Salt states reference `dotfiles/` without adding ignore entries

### Alternatives Considered
- **Integrate into `lint-jinja.py`**: Rejected. lint-jinja.py is already 989 lines. A focused single-purpose script is easier to maintain and understand.
- **Shell script**: Rejected. Python aligns with all other lint scripts in the project.

## R4: `.chezmoiignore` as Source of Truth

### Decision
`.chezmoiignore` serves as the living inventory of Salt-owned files within the `dotfiles/` tree. The lint script uses it as the reference for what's allowed.

### Rationale
- `.chezmoiignore` already exists with 3 entries
- Adding floorp entries makes it a complete inventory
- The lint script can read this file and compare against Salt state references
- Single file to maintain, no separate inventory needed

### Alternatives Considered
- **Separate `ownership.yaml` manifest**: Rejected. Adds maintenance burden. `.chezmoiignore` already serves this purpose.
