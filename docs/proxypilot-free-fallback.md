# ProxyPilot Free Model Fallback

## Overview

Emergency fallback system providing free AI model access when paid providers (Anthropic, Google Gemini) are unavailable. Uses 3 cloud providers + local Ollama as last resort.

## Architecture

- ProxyPilot's `openai-compatibility` section routes requests to free providers
- Alias pooling: shared `fallback-*` aliases enable round-robin across providers
- Emergency-only: free providers are only reachable via dedicated `fallback-*` model names
- Cascading: Groq -> Cerebras -> OpenRouter -> Ollama (local)

## Providers

| Priority | Provider | Models | Alias | Rate Limits |
|----------|----------|--------|-------|-------------|
| 1 | Groq | llama-3.3-70b-versatile | fallback-large | 1K RPD |
| 1 | Groq | qwen/qwen3-32b | fallback-medium | 1K RPD |
| 2 | Cerebras | qwen-3-235b-a22b-instruct | fallback-large | 1M tokens/day |
| 2 | Cerebras | llama3.1-8b | fallback-small | 1M tokens/day |
| 3 | OpenRouter | qwen/qwen3-coder-480b-a35b:free | fallback-code | 200 RPD |
| 3 | OpenRouter | openrouter/auto | fallback-large | 200 RPD |
| 4 | Ollama | qwen3.5:27b | fallback-large | Local GPU |
| 4 | Ollama | qwen2.5-coder:7b | fallback-code | Local GPU |
| 4 | Ollama | qwen3:14b | fallback-medium | Local GPU |

Excluded providers:

- Mistral -- blocks signups from Russia
- SambaNova -- no access from Russia

## Alias Coverage

| Alias | Providers | Models |
|-------|-----------|--------|
| fallback-large | Groq, Cerebras, OpenRouter, Ollama | 4 models across 4 providers |
| fallback-code | OpenRouter, Ollama | 2 models across 2 providers |
| fallback-medium | Groq, Ollama | 2 models across 2 providers |
| fallback-small | Cerebras | 1 model, 1 provider |

## Secrets (gopass)

| Path | Provider | Signup URL |
|------|----------|------------|
| `api/groq` | Groq | https://console.groq.com |
| `api/cerebras` | Cerebras | https://cloud.cerebras.ai |
| `api/openrouter` | OpenRouter | https://openrouter.ai/keys |

## Adding a Provider

1. Add entry to `states/data/free_providers.yaml`
2. Store API key: `gopass insert api/<name>`
3. Run `scripts/bootstrap-free-providers.sh` to seed the config
4. Run `just` to deploy

Only 2 files changed (data file + gopass secret) -- no code modifications needed.

## Removing a Provider

1. Remove entry from `states/data/free_providers.yaml`
2. Run `just` to deploy
3. Optionally: `gopass rm api/<name>`

## First-Time Setup

```bash
# 1. Sign up and get API keys from each provider
# 2. Store keys in gopass
gopass insert api/groq
gopass insert api/cerebras
gopass insert api/openrouter

# 3. Run bootstrap to seed ProxyPilot config
scripts/bootstrap-free-providers.sh

# 4. Deploy via Salt
just

# 5. Restart ProxyPilot
systemctl --user restart proxypilot

# 6. Verify
curl http://127.0.0.1:8317/v1/chat/completions \
  -H "Authorization: Bearer $(gopass show -o api/proxypilot-local)" \
  -H "Content-Type: application/json" \
  -d '{"model":"fallback-large","messages":[{"role":"user","content":"Hello"}],"max_tokens":10}'
```

## Troubleshooting

### Provider not responding

- Check gopass key exists: `scripts/bootstrap-free-providers.sh --check`
- Check ProxyPilot logs: `journalctl --user -u proxypilot -f`
- Re-seed config: `scripts/bootstrap-free-providers.sh`

### Keys missing after `just`

gopass requires user-level GPG agent (Yubikey) which is unavailable in Salt's root context. The AWK fallback reads keys from the already-deployed config. If keys are missing:

1. Run `scripts/bootstrap-free-providers.sh` to re-inject from gopass
2. Subsequent `just` runs will maintain keys via AWK

### Model deprecated by provider

Update model name in `states/data/free_providers.yaml` and run `just`.

## Monitoring

Grafana dashboard at `http://127.0.0.1:3000` -> ProxyPilot dashboard -> "Fallback Providers" row:

- **Fallback Activation**: Count of requests routed to free providers
- **Provider Error Rates**: Per-provider 4xx/5xx errors over time
- **Ollama Fallback**: Count of requests reaching local Ollama last-resort

## Configuration Files

| File | Purpose |
|------|---------|
| `states/data/free_providers.yaml` | Provider definitions (data-driven) |
| `states/configs/proxypilot.yaml.j2` | ProxyPilot config template (renders providers) |
| `states/opencode.sls` | Salt state (imports data, resolves keys) |
| `scripts/bootstrap-free-providers.sh` | First-time key seeder |
| `states/configs/grafana-dashboard-proxypilot.json` | Grafana dashboard |
