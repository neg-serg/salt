# Research: Activate OpenClaw Telegram Bot

**Date**: 2026-03-08

## R1: OpenClaw Provider API Type for ProxyPilot

**Decision**: Use `openai-completions` API type for the ProxyPilot provider.

**Rationale**: ProxyPilot exposes an OpenAI-compatible endpoint at `http://127.0.0.1:8317`. OpenClaw supports `openai-completions` as one of its API types (alongside `anthropic-messages`, `google-generative-ai`, etc.). The current config uses `anthropic-messages` for direct Anthropic API — this must change to `openai-completions` for ProxyPilot routing.

**Alternatives considered**:
- `anthropic-messages` — only works with direct Anthropic API, not through ProxyPilot's OpenAI-compatible proxy
- `openai-responses` — newer OpenAI API format, ProxyPilot uses the completions (chat) format

## R2: Model ID Format for ProxyPilot

**Decision**: Use `claude-sonnet-4-6` as the model ID (short alias without date suffix).

**Rationale**: ProxyPilot's `oauth-model-alias` section maps `claude-sonnet-4-6` → Anthropic's Claude Sonnet 4.6 via Antigravity OAuth. The full date-suffixed ID (`claude-sonnet-4-6-20250514`) is the Anthropic API format; ProxyPilot uses its own alias system. In OpenClaw's config, the model reference will be `proxypilot/claude-sonnet-4-6` (provider-name/model-id).

**Alternatives considered**:
- `claude-sonnet-4-6-20250514` — Anthropic-native ID, may not match ProxyPilot alias
- `claude-opus-4-6` — higher quality but slower, Sonnet is better for chat responsiveness

## R3: Force-Redeploy Mechanism

**Decision**: Add an idempotent `cmd.run` state that deletes the existing config file when it still contains the old Anthropic provider, before the `file.managed` state runs.

**Rationale**: The `replace: False` on `file.managed` prevents overwrites — including our updated template. We need a one-shot migration: delete the old config → `file.managed` creates the new one → subsequent applies skip both (file exists with correct provider, and the delete guard passes because `openai-completions` is present).

**Implementation**:
```yaml
openclaw_config_migrate:
  cmd.run:
    - name: rm -f {{ home }}/.openclaw/openclaw.json
    - onlyif: test -f {{ home }}/.openclaw/openclaw.json
    - unless: grep -q 'openai-completions' {{ home }}/.openclaw/openclaw.json
    - require:
      - file: openclaw_config_dir
```

**Alternatives considered**:
- Removing `replace: False` — would overwrite OpenClaw's runtime config modifications on every apply
- Manual deletion — not idempotent, requires human intervention
- Using `file.absent` + `file.managed` — less clear intent than a migration-specific state

## R4: Systemd Dependency on ProxyPilot

**Decision**: Add `Wants=proxypilot.service` and `After=proxypilot.service` to `openclaw-gateway.service`.

**Rationale**: OpenClaw needs ProxyPilot running to route model requests. `Wants=` (not `Requires=`) ensures ProxyPilot starts alongside OpenClaw but doesn't fail-cascade if ProxyPilot crashes temporarily. `After=` ensures startup ordering. This matches the CLAUDE.md documentation that mentions `Requires=proxypilot.service` but uses the softer `Wants=` to avoid unnecessary failures.

**Alternatives considered**:
- `Requires=proxypilot.service` — too strict, would stop OpenClaw if ProxyPilot restarts
- No dependency — ProxyPilot might not be ready when OpenClaw starts, causing initial connection failures

## R5: Proxy Key Already Available

**Decision**: Use the existing `proxy_key` template variable, which is already resolved and passed to the template context.

**Rationale**: `openclaw_agent.sls` already resolves `_proxy_key` via the gopass fallback pattern (gopass primary → awk parse of proxypilot config). It's passed to the template as `proxy_key` but currently unused. No new secret resolution needed.

## R6: Telegram Integration Already Configured

**Decision**: No changes needed to Telegram channel configuration — it's already correctly implemented.

**Rationale**: The conditional Telegram block in `openclaw.json.j2` (lines 52-67) correctly:
- Only includes Telegram config when `telegram_token` is non-empty
- Sets `dmPolicy: "allowlist"` with `allowFrom: [telegram_uid]`
- Sets `groupPolicy: "disabled"`
- Uses `dmScope: "per-channel-peer"` for session isolation

The Salt state resolves `_telegram_token` and `_telegram_uid` from gopass with proper fallback.
