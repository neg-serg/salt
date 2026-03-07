# OpenCode Antigravity Auth Plugin

## Overview

[opencode-antigravity-auth](https://github.com/NoeFabris/opencode-antigravity-auth) is an OpenCode plugin
that provides access to Claude and Gemini models via Google Antigravity OAuth.
It uses Google's IDE quota pools, giving access to models like Claude Opus 4.6 and Gemini 3.1 Pro
without direct API keys.

**Status: DISABLED** — the primary Google account (`serg.zorg@gmail.com`) is TOS-banned.
A new Google account is required to re-enable.

## Blocked Account

| Field | Value |
|---|---|
| Email | `serg.zorg@gmail.com` |
| Project | `rising-fact-p41fc` |
| Error | 403 — "This service has been disabled in this account for violation of Terms of Service" |
| Date blocked | Before 2026-03-07 |

This is the same account that blocks Gemini/Antigravity routes in ProxyPilot.
An appeal was submitted but has not been resolved.

**Do not attempt to re-use this account** — it will always return 403 on Antigravity endpoints.

## ToS Warning

Google actively bans accounts that use Antigravity proxies or unofficial plugins.
Using this plugin carries a risk of account suspension.
Do not use a Google account that has important data (Drive, Gmail, etc.).

## How to Re-enable (with a New Account)

### 1. Add the plugin to opencode.json

Edit `dotfiles/dot_config/opencode/opencode.json`:

```json
{
  "plugin": ["opencode-antigravity-auth@latest"],
  "enabled_providers": ["openai", "google"],
  "provider": {
    "google": {
      "models": {
        "antigravity-gemini-3-pro": {
          "name": "Gemini 3 Pro (Antigravity)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingLevel": "low" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-gemini-3.1-pro": {
          "name": "Gemini 3.1 Pro (Antigravity)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingLevel": "low" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-gemini-3-flash": {
          "name": "Gemini 3 Flash (Antigravity)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "minimal": { "thinkingLevel": "minimal" },
            "low": { "thinkingLevel": "low" },
            "medium": { "thinkingLevel": "medium" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-claude-sonnet-4-6": {
          "name": "Claude Sonnet 4.6 (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "antigravity-claude-opus-4-6-thinking": {
          "name": "Claude Opus 4.6 Thinking (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingConfig": { "thinkingBudget": 8192 } },
            "max": { "thinkingConfig": { "thinkingBudget": 32768 } }
          }
        },
        "gemini-2.5-flash": {
          "name": "Gemini 2.5 Flash (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-2.5-pro": {
          "name": "Gemini 2.5 Pro (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3-flash-preview": {
          "name": "Gemini 3 Flash Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3-pro-preview": {
          "name": "Gemini 3 Pro Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3.1-pro-preview": {
          "name": "Gemini 3.1 Pro Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3.1-pro-preview-customtools": {
          "name": "Gemini 3.1 Pro Preview Custom Tools (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        }
      }
    }
  }
}
```

### 2. Remove the old account data

```bash
rm ~/.config/opencode/antigravity-accounts.json
```

### 3. Authenticate with a new Google account

```bash
opencode auth login
# Select: Google → OAuth with Google (Antigravity)
# Complete the browser flow with a NEW account (not serg.zorg@gmail.com)
```

### 4. Apply config and verify

```bash
chezmoi apply ~/.config/opencode/opencode.json
opencode run "Hello" --model=google/antigravity-claude-opus-4-6-thinking --variant=max
```

## Available Models

**Antigravity quota** (Google IDE pool):
- `antigravity-gemini-3-pro` / `antigravity-gemini-3.1-pro` — thinking variants: low, high
- `antigravity-gemini-3-flash` — thinking variants: minimal, low, medium, high
- `antigravity-claude-sonnet-4-6` — no variants
- `antigravity-claude-opus-4-6-thinking` — variants: low (8K budget), max (32K budget)

**Gemini CLI quota** (separate pool):
- `gemini-2.5-flash`, `gemini-2.5-pro`
- `gemini-3-flash-preview`, `gemini-3-pro-preview`
- `gemini-3.1-pro-preview`, `gemini-3.1-pro-preview-customtools`

## Config Files

| File | Purpose |
|---|---|
| `~/.config/opencode/opencode.json` | Main config (plugin + model definitions) |
| `~/.config/opencode/antigravity-accounts.json` | OAuth accounts and tokens |
| `~/.config/opencode/antigravity.json` | Plugin settings |
| `~/.config/opencode/antigravity-logs/` | Debug logs |

## Troubleshooting

**403 "service disabled"**: The Google account is TOS-banned. Delete `antigravity-accounts.json` and authenticate with a different account.

**Reset all state**: `rm ~/.config/opencode/antigravity-accounts.json ~/.config/opencode/antigravity.json`

**Multi-account rotation**: The plugin supports multiple accounts. Run `opencode auth login` again to add more. Rotation is automatic when rate-limited.
