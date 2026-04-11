# ProxyPilot Setup Guide

## Overview

ProxyPilot is a local AI API proxy that routes requests from coding tools
(Claude Code, OpenCode) to upstream providers via OAuth tokens.
It runs as a systemd user service on `127.0.0.1:8317`.

## Architecture

```
claude (direct)                  claude-proxy (wrapper)
    │                                │
    │ ANTHROPIC_BASE_URL unset       │ ANTHROPIC_BASE_URL=127.0.0.1:8317
    │ CLAUDE_CONFIG_DIR unset        │ CLAUDE_CONFIG_DIR=~/.claude-proxy
    ▼                                ▼
┌───────────┐                 ┌─────────────────────┐
│ Anthropic │                 │  ProxyPilot         │  ← systemd user service
│ API       │                 │  127.0.0.1:8317     │
└───────────┘                 └──────────┬──────────┘
                                         │
                              │
                              ▼
                        ┌──────────┐
                        │ Claude   │
                        │ OAuth    │
                        └──────────┘
                        ~/.cli-proxy-api/
```

## Components

| Component | Path / Detail |
|-----------|---------------|
| Binary | `~/.local/bin/proxypilot` (GitHub release) |
| Version | Pinned in `states/data/versions.yaml` |
| Config (chezmoi) | `dotfiles/dot_config/proxypilot/config.yaml.tmpl` |
| Config (Salt) | `states/configs/proxypilot.yaml.j2` |
| Deployed config | `~/.config/proxypilot/config.yaml` |
| Service unit | `states/units/user/proxypilot.service` |
| OAuth tokens | `~/.cli-proxy-api/` (auto-created by ProxyPilot) |
| Wrapper | `~/.local/bin/claude-proxy` (zsh script) |
| Proxy config dir | `~/.claude-proxy/` (isolated from `~/.claude/`) |
| Listen | `127.0.0.1:8317` |
| Grafana dashboard | `states/configs/grafana-dashboard-proxypilot.json` |

## Environment Isolation

The direct `claude` CLI and the proxied `claude-proxy` wrapper are fully isolated:

| | `claude` (direct) | `claude-proxy` (via ProxyPilot) |
|---|---|---|
| Config dir | `~/.claude/` | `~/.claude-proxy/` |
| Credentials | `~/.claude/.credentials.json` | ProxyPilot OAuth tokens |
| History | `~/.claude/history.jsonl` | `~/.claude-proxy/history.jsonl` |
| Settings | `~/.claude/settings.json` | `~/.claude-proxy/settings.json` |
| `ANTHROPIC_BASE_URL` | unset (api.anthropic.com) | `http://127.0.0.1:8317` |
| `ANTHROPIC_API_KEY` | unset (from credentials) | ProxyPilot API key |
| `CLAUDE_CONFIG_DIR` | unset (`~/.claude/`) | `~/.claude-proxy` |

The wrapper uses `exec env` to set variables **only for the child process**.
No global exports exist in `.zshenv`, `environment.d`, or systemd user env.

### Safety guarantees

- `ANTHROPIC_BASE_URL` is **never** exported globally
- `ANTHROPIC_API_KEY` is **never** exported globally
- ProxyPilot service unit has **no** `Environment=` directives
- `--setup-claude` / `--setup-all` are **never** run automatically
- Even if `--setup-claude` were run, it would modify `~/.claude-proxy/settings.json`
  (the proxy config dir), not `~/.claude/settings.json`

## OAuth Providers

ProxyPilot authenticates to upstream providers via OAuth tokens stored in `~/.cli-proxy-api/`:

| Provider | Login command | Token file | Status |
|----------|---------------|------------|--------|
| Claude | `--claude-login` | `claude-<email>.json` | Working (v0.3.0-dev-0.40+) |

### Claude OAuth

Fixed in v0.3.0-dev-0.40. Native Anthropic OAuth flow (not Google Cloud).

```bash
proxypilot -config ~/.config/proxypilot/config.yaml -claude-login
```

Opens browser, completes OAuth, saves token. No manual steps needed.

## Config Structure

The config (`~/.config/proxypilot/config.yaml`) is deployed by Salt via `opencode.sls`,
not chezmoi (chezmoi only creates the parent directory).

Key sections:

```yaml
# Authentication — clients use this key to talk to the proxy
api-keys:
  - "<from gopass api/proxypilot-local>"

# Model aliases — maps client model names to providers
# alias = what the client sends, name = upstream model ID
```

Two template sources must stay in sync:
- `dotfiles/dot_config/proxypilot/config.yaml.tmpl` — chezmoi template
- `states/configs/proxypilot.yaml.j2` — Salt Jinja template

## Secrets

| Secret | gopass path | Used by |
|--------|-------------|---------|
| Client API key | `api/proxypilot-local` | Claude Code, OpenCode, NanoClaw |
| Management key | `api/proxypilot-management` | Web dashboard access |

The client API key is also exported as `PROXYPILOT_API_KEY` and `OPENAI_API_KEY`
in `~/.config/zsh/10-secrets.zsh` (for shell tools).

## Usage

### Direct Claude (default)

```bash
claude  # goes to api.anthropic.com, uses ~/.claude/
```

### Proxied Claude

```bash
claude-proxy  # goes through ProxyPilot, uses ~/.claude-proxy/
```

Requires `PROXYPILOT_API_KEY` to be set (sourced from `10-secrets.zsh`).

### Service management

```bash
systemctl --user status proxypilot
systemctl --user restart proxypilot
journalctl --user -u proxypilot -f  # live logs
```

### Re-authenticate

```bash
# Stop service first to avoid token conflicts
systemctl --user stop proxypilot

# Claude (Anthropic OAuth)
proxypilot -config ~/.config/proxypilot/config.yaml -claude-login

systemctl --user start proxypilot
```

### Check status

```bash
proxypilot -config ~/.config/proxypilot/config.yaml -list-accounts
proxypilot -config ~/.config/proxypilot/config.yaml -list-models
proxypilot -config ~/.config/proxypilot/config.yaml -detect-agents
```

## Upgrading

1. Check for new releases: `gh release list --repo Finesssee/ProxyPilot --limit 5`
2. Update version in `states/data/versions.yaml`
3. Download new binary, get its hash: `sha256sum proxypilot-linux-amd64`
4. Update hash in `states/data/installers.yaml`
5. Run `just` to validate Salt renders

## Version History

| Version | Key changes |
|---------|-------------|
| v0.3.0-dev-0.39 | `tui` flag panic on all `--*-login` commands |
| v0.3.0-dev-0.40 | Fixed `tui` panic, Claude OAuth works, Gemini 3.1/GPT-5.4 support |

## Dangerous Commands

These commands **modify agent config files** and should never be run
unless you explicitly want to redirect an agent through ProxyPilot:

```bash
# DO NOT RUN unless intentional:
proxypilot --setup-claude    # modifies ~/.claude/settings.json
proxypilot --setup-all       # modifies ALL detected agent configs
```

These inject `ANTHROPIC_BASE_URL` into the agent's settings, which redirects
all traffic through ProxyPilot. Use the `claude-proxy` wrapper instead.
