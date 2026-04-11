# salt

> [Русская версия](README.ru.md)

Salt states + chezmoi dotfiles for CachyOS (Arch-based) workstation configuration.

## Structure

| Path | Purpose |
|---|---|
| `states/` | Salt state files (.sls) and Jinja macros |
| `dotfiles/` | Chezmoi source directory |
| `scripts/` | Utility scripts (apply, lint, daemon) |
| `build/` | Custom package build configs (Iosevka, PKGBUILDs) |
| `docs/` | Setup guides and reference |

## Usage

```bash
# Apply everything (system_description → all states)
just apply

# Apply a single state
just apply desktop
just apply nanoclaw

# Apply a state group (subset of related states)
just group core
just group desktop
just group ai

# Dry run (no changes)
just test
just test group/network
```

### State groups

Groups let you apply a coherent slice of the system without running all
~200 states.  Useful for fixing one broken area or bootstrapping incrementally.

| Group | What it covers | Typical run time |
|-------|---------------|-----------------|
| `core` | users, zsh, mounts, kernel, hardware, systemd_resources | ~0.6 s |
| `network` | dns, network | ~0.1 s |
| `desktop` | audio, desktop (hyprland, portals, packages), fonts | ~0.7 s |
| `packages` | pacman packages, all installers, custom PKGBUILDs | ~0.6 s |
| `services` | system services, monitoring, user systemd units | ~0.5 s |
| `ai` | ollama, llama_embed, nanoclaw, opencode, image_gen (feature-gated) | ~0.4 s |

Groups live in `states/group/*.sls`.  Each is a thin `include:` list — no
new logic, just a convenient entry point.  Individual states still work:
`just apply mpd`, `just apply steam`, etc.

## Documentation

- [Host setup](docs/adding-host.md) — adding a new machine
- [Deployment](docs/deploy-cachyos.md) — fresh CachyOS install
- [Secrets](docs/secrets-scheme.md) — `gopass`-backed secret management with approved `gpg` and `age` backends
- [gopass setup](docs/gopass-setup.md) — step-by-step secret provisioning, unlock, backup, and migration guidance
- [gopass age recovery](docs/gopass-age-recovery.md) — moving an `age`-backed store to another machine
