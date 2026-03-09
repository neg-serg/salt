# Quickstart: Chezmoi/Salt File Ownership Boundary

**Branch**: `007-chezmoi-salt-boundary` | **Date**: 2026-03-09

## What This Feature Does

Eliminates dual-write conflicts where both Salt and chezmoi deploy the same configuration files. Establishes a clear ownership policy enforced by an automated lint script.

## Changes At a Glance

1. **Add 5 floorp paths to `.chezmoiignore`** — prevents chezmoi from deploying to wrong location
2. **Delete proxypilot chezmoi template** — Salt's Jinja2 template is the sole source
3. **New lint script** (`scripts/lint-ownership.py`) — detects `salt://dotfiles/` references not covered by `.chezmoiignore`
4. **Update Justfile** — add `lint-ownership.py` to `just lint`
5. **Document ownership policy in CLAUDE.md** — decision framework for future files

## How to Verify

```bash
# Run lint to check for ownership violations
just lint

# Apply Salt (should report 0 failures)
just apply

# Apply chezmoi (should report 0 errors)
chezmoi apply

# Check that no file is deployed by both
grep 'salt://dotfiles/' states/*.sls | \
  while read line; do
    path=$(echo "$line" | grep -oP "salt://dotfiles/\K[^ '\"]+")
    chezmoi_path=$(echo "$path" | sed 's|^dot_config/|.config/|; s|^dot_local/|.local/|')
    if ! grep -qF "$chezmoi_path" dotfiles/.chezmoiignore 2>/dev/null; then
      echo "VIOLATION: $chezmoi_path not in .chezmoiignore"
    fi
  done
```

## Ownership Decision Tree

```
New config file?
├── Needs gopass secrets with fallback? → Salt
├── Triggers service restart (watch/onchanges)? → Salt
├── Deployed to non-XDG path (e.g., ~/.floorp/<profile>/)? → Salt
├── Conditional on Salt grains/pillar? → Salt
└── Purely declarative dotfile? → Chezmoi
```
