# Quickstart: Activate OpenClaw Telegram Bot

**Date**: 2026-03-08

## Files to Modify

1. **`states/configs/openclaw.json.j2`** — Replace Anthropic provider with ProxyPilot provider
2. **`states/units/user/openclaw-gateway.service`** — Add ProxyPilot dependency
3. **`states/openclaw_agent.sls`** — Add config migration state

## Change Summary

### 1. Config Template (`openclaw.json.j2`)

- Remove `anthropic` provider block (baseUrl `https://api.anthropic.com`, api `anthropic-messages`)
- Add `proxypilot` provider block (baseUrl `http://127.0.0.1:8317`, api `openai-completions`, apiKey from `proxy_key`)
- Update `agents.defaults.model.primary` to `proxypilot/claude-sonnet-4-6`
- Update `agents.defaults.model.fallbacks` to `["proxypilot/claude-opus-4-6"]`
- Add models: `claude-sonnet-4-6`, `claude-opus-4-6` with 200k context / 16k output

### 2. Systemd Unit (`openclaw-gateway.service`)

- Add `Wants=proxypilot.service` to `[Unit]`
- Add `proxypilot.service` to `After=` line

### 3. Salt State (`openclaw_agent.sls`)

- Add `openclaw_config_migrate` state before `openclaw_config`:
  - `cmd.run: rm -f ~/.openclaw/openclaw.json`
  - `onlyif: test -f ~/.openclaw/openclaw.json`
  - `unless: grep -q 'openai-completions' ~/.openclaw/openclaw.json`
- Remove `_anthropic_key` variable (no longer needed)
- Remove `anthropic_key` from template context

## Verification Steps

```bash
# 1. Apply Salt
just

# 2. Check service status
systemctl --user status openclaw-gateway proxypilot

# 3. Check config has ProxyPilot
grep 'openai-completions' ~/.openclaw/openclaw.json

# 4. Check models
openclaw models list

# 5. Check logs
journalctl --user -u openclaw-gateway -f

# 6. Send test message via Telegram
# Send "Привет" to @negserg_openclaw_bot
```
