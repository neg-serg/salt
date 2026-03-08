# Data Model: Activate OpenClaw Telegram Bot

**Date**: 2026-03-08

This feature modifies configuration files, not database entities. The "data model" is the config schema.

## Entity: OpenClaw Config (`openclaw.json`)

### Provider Block (changed)

| Field | Type | Value | Notes |
|-------|------|-------|-------|
| `models.providers.proxypilot.baseUrl` | string | `http://127.0.0.1:8317` | ProxyPilot local endpoint |
| `models.providers.proxypilot.apiKey` | string | (from gopass) | `api/proxypilot-local` secret |
| `models.providers.proxypilot.api` | string | `openai-completions` | OpenAI-compatible API type |
| `models.providers.proxypilot.models[].id` | string | e.g., `claude-sonnet-4-6` | ProxyPilot alias format |
| `models.providers.proxypilot.models[].name` | string | Display name | Human-readable |
| `models.providers.proxypilot.models[].contextWindow` | int | `200000` | Token limit |
| `models.providers.proxypilot.models[].maxTokens` | int | `16384` | Output token limit |

### Agent Defaults (changed)

| Field | Type | Value | Notes |
|-------|------|-------|-------|
| `agents.defaults.model.primary` | string | `proxypilot/claude-sonnet-4-6` | Provider/model-id format |
| `agents.defaults.model.fallbacks` | string[] | `["proxypilot/claude-opus-4-6"]` | Fallback model list |

### Telegram Channel (unchanged)

| Field | Type | Value | Notes |
|-------|------|-------|-------|
| `channels.telegram.enabled` | bool | `true` | Conditional on token |
| `channels.telegram.botToken` | string | (from gopass) | `api/openclaw-telegram` |
| `channels.telegram.dmPolicy` | string | `allowlist` | Only allowlisted users |
| `channels.telegram.allowFrom` | string[] | (from gopass) | `api/openclaw-telegram-uid` |
| `channels.telegram.groupPolicy` | string | `disabled` | No group responses |

## Entity: Systemd Unit (`openclaw-gateway.service`)

### Dependencies (added)

| Field | Value | Notes |
|-------|-------|-------|
| `Wants` | `proxypilot.service` | Soft dependency |
| `After` | `network-online.target proxypilot.service` | Startup ordering |

## Entity: Salt State (`openclaw_agent.sls`)

### Migration State (new)

| State ID | Type | Guard | Purpose |
|----------|------|-------|---------|
| `openclaw_config_migrate` | `cmd.run` | `onlyif` + `unless` | Delete old Anthropic-only config |

The `onlyif` checks the file exists; `unless` checks it already has `openai-completions`. This ensures the migration runs exactly once.
