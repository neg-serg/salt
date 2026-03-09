# Data Model: Chezmoi/Salt File Ownership Boundary

**Branch**: `007-chezmoi-salt-boundary` | **Date**: 2026-03-09

## Entities

### Owned File

A configuration file with a single designated management tool.

| Attribute | Description |
|-----------|-------------|
| deploy_path | Target path on the system (e.g., `~/.floorp/<profile>/user.js`) |
| source_path | Source in the repository (e.g., `dotfiles/dot_config/floorp/user.js`) |
| owner | `salt` or `chezmoi` |
| salt_source_uri | Salt file server URI if Salt-owned (e.g., `salt://dotfiles/dot_config/floorp/user.js`) |
| ownership_reason | Why this tool owns it: `secrets`, `trigger`, `profile-path`, `declarative` |

### Ownership Registry (`.chezmoiignore`)

The living inventory of files that exist in `dotfiles/` but are owned by Salt.

| Attribute | Description |
|-----------|-------------|
| path | Chezmoi-relative path (e.g., `.config/mpd/mpd.conf`) |
| comment | Group comment explaining why these are Salt-owned |

### Current State

```
.chezmoiignore (before):
  .config/proxypilot/config.yaml    # Salt: secrets + gopass fallback
  .config/mpd/mpd.conf              # Salt: service require chain
  .config/systemd/user/mpdas.service # Salt: user_service_file macro

.chezmoiignore (after):
  .config/proxypilot/config.yaml    # Salt: secrets + gopass fallback
  .config/mpd/mpd.conf              # Salt: service require chain
  .config/systemd/user/mpdas.service # Salt: user_service_file macro
  .config/floorp/user.js            # Salt: profile-path + onchanges trigger
  .config/floorp/userChrome.css     # Salt: profile-path deployment
  .config/floorp/userContent.css    # Salt: profile-path deployment
  .config/floorp/custom/            # Salt: profile-path deployment
```

### File Lifecycle States

```
[Not Tracked] → [Added to dotfiles/] → Decision Point:
  ├── Purely declarative → Chezmoi owns (no .chezmoiignore entry)
  └── Needs Salt features → Salt owns:
        ├── Source in dotfiles/ → Add to .chezmoiignore
        └── Source in configs/ → Delete from dotfiles/ (or never add)
```

## Relationships

- An Owned File belongs to exactly one owner (1:1)
- Salt-owned files in `dotfiles/` MUST have a corresponding `.chezmoiignore` entry (enforced by lint)
- Salt-owned files with separate sources (e.g., `salt://configs/`) MUST NOT exist in `dotfiles/`
