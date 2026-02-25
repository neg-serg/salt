# salt

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
# Apply Salt states + chezmoi dotfiles
scripts/salt-apply.sh

# Apply specific state
scripts/salt-apply.sh desktop

# Dry run
scripts/salt-apply.sh --test
```

## Documentation

- [Host setup](docs/adding-host.md) — adding a new machine
- [Deployment](docs/deploy-cachyos.md) — fresh CachyOS install
- [Secrets](docs/secrets-scheme.md) — gopass/Yubikey integration
- [gopass setup](docs/gopass-setup.md) — step-by-step secret provisioning
