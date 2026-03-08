# Quickstart: ProxyPilot Free Model Fallback

**Date**: 2026-03-08 | **Branch**: `003-proxypilot-free-fallback`

## Prerequisites

1. ProxyPilot v0.3.0-dev-0.40+ installed (`~/.local/bin/proxypilot`)
2. Ollama running locally on port 11434 with models pulled
3. gopass configured with GPG + Yubikey
4. Salt + chezmoi operational

## Step 1: Obtain Free Provider API Keys

Sign up at each provider (no credit card required):

| Provider | Signup URL | API Key Location |
|----------|-----------|-----------------|
| Groq | console.groq.com | API Keys page |
| Mistral | console.mistral.ai | API Keys page |
| Cerebras | cloud.cerebras.ai | API Keys in settings |
| OpenRouter | openrouter.ai/keys | Keys page |
| SambaNova | cloud.sambanova.ai | API Keys in dashboard |

## Step 2: Store API Keys in gopass

```bash
gopass insert api/groq
gopass insert api/mistral
gopass insert api/cerebras
gopass insert api/openrouter
gopass insert api/sambanova
```

## Step 3: Apply Salt States

```bash
just
```

This runs the default `system_description` target, which:
1. Reads `states/data/free_providers.yaml` for provider definitions
2. Resolves API keys from gopass via `gopass_secret()` macro
3. Renders `states/configs/proxypilot.yaml.j2` with the new `openai-compatibility` section
4. Deploys to `~/.config/proxypilot/config.yaml`
5. Restarts `proxypilot.service` on config change
6. Deploys updated Grafana dashboard with fallback panels

## Step 4: Verify

Test fallback model routing:

```bash
# Test Groq via ProxyPilot
curl -s http://127.0.0.1:8317/v1/chat/completions \
  -H "Authorization: Bearer $(gopass show -o api/proxypilot-local)" \
  -H "Content-Type: application/json" \
  -d '{"model": "fallback-large", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 50}'

# Test Ollama last-resort
curl -s http://127.0.0.1:8317/v1/chat/completions \
  -H "Authorization: Bearer $(gopass show -o api/proxypilot-local)" \
  -H "Content-Type: application/json" \
  -d '{"model": "ollama/qwen3", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 50}'

# List available models
curl -s http://127.0.0.1:8317/v1/models \
  -H "Authorization: Bearer $(gopass show -o api/proxypilot-local)" | jq '.data[].id'
```

## Step 5: Check Grafana Dashboard

Open `http://127.0.0.1:3000` → ProxyPilot dashboard → "Fallback Providers" row.

Panels show:
- Fallback activation count (should be 0 during normal operation)
- Per-provider error rates
- Ollama fallback usage

## Adding a New Provider

1. Add entry to `states/data/free_providers.yaml`
2. Store API key: `gopass insert api/<provider-name>`
3. Run `just`

## Removing a Provider

1. Remove entry from `states/data/free_providers.yaml`
2. Optionally remove gopass secret: `gopass rm api/<provider-name>`
3. Run `just`
