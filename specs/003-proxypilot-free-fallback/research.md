# Research: ProxyPilot Free Model Fallback

**Date**: 2026-03-08 | **Branch**: `003-proxypilot-free-fallback`

## Decision 1: ProxyPilot Backend Provider Config Format

**Decision**: Use the `openai-compatibility` config section for all free cloud providers and local Ollama.

**Rationale**: ProxyPilot (built on CLIProxyAPI engine) natively supports an `openai-compatibility` section for any OpenAI-compatible endpoint with direct API keys. This section supports:
- Custom `base-url` per provider
- Multiple `api-key-entries` with round-robin rotation
- `models` array with `name`/`alias` mapping for route disambiguation
- `prefix` field for namespace isolation (e.g., `groq/model-name`)

All 5 recommended free providers and Ollama use OpenAI-compatible `/v1/chat/completions` endpoints, making `openai-compatibility` the universal integration point.

**Alternatives considered**:
- `claude-api-key` section: Only for Anthropic native API — not applicable to free providers
- `gemini-api-key` section: Only for Google Gemini native API — not applicable
- Custom proxy middleware: Over-engineered; ProxyPilot already handles format translation

**Source**: [CLIProxyAPI config reference](https://help.router-for.me/configuration/options), [OpenAI compatibility docs](https://help.router-for.me/configuration/provider/openai-compatibility)

## Decision 2: Config Deployment Path

**Decision**: Modify Salt template only (`states/configs/proxypilot.yaml.j2`). Do not modify chezmoi template.

**Rationale**: The chezmoi `.chezmoiignore` file explicitly ignores `.config/proxypilot/config.yaml`. Salt is the sole deployer of this file via `states/opencode.sls` → `salt://configs/proxypilot.yaml.j2`. Modifying the chezmoi template would have no effect on deployment and would create a maintenance burden of keeping two templates in sync.

**Alternatives considered**:
- Modify both templates: Redundant — chezmoi ignores the file
- Switch to chezmoi-only deployment: Would break gopass secret injection pattern already established in Salt

## Decision 3: Free Provider Selection

**Decision**: Deploy 5 cloud providers (Groq, Mistral, Cerebras, OpenRouter, SambaNova) + local Ollama.

**Rationale**: All 5 providers meet the spec requirements: OpenAI-compatible API, no credit card, generous free tiers. Combined daily capacity exceeds any realistic emergency fallback usage. Research details:

| Provider | Base URL | Key Models for Coding | Rate Limits (Free) | Signup |
|----------|----------|----------------------|-------------------|--------|
| Groq | `api.groq.com/openai/v1` | llama-3.3-70b-versatile, qwen/qwen3-32b | 30 RPM, 1K RPD | No CC |
| Mistral | `api.mistral.ai/v1` | mistral-small-latest, codestral-latest | 1 RPS, 1B tokens/mo | No CC |
| Cerebras | `api.cerebras.ai/v1` | qwen-3-235b-a22b-instruct, llama3.1-8b | 30 RPM, 1M tokens/day | No CC |
| OpenRouter | `openrouter.ai/api/v1` | qwen/qwen3-coder-480b-a35b:free, openrouter/auto | 20 RPM, 200 RPD | No CC |
| SambaNova | `api.sambanova.ai/v1` | Meta-Llama-3.3-70B-Instruct, Meta-Llama-3.1-8B-Instruct | 20 RPM | No CC |
| Ollama | `localhost:11434/v1` | qwen3.5:27b, qwen3:14b, qwen2.5-coder:7b, gemma3:12b | GPU-bound | Local |

**Alternatives considered**:
- Together AI: Requires credit card for signup — violates SC-005
- Cloudflare Workers AI: Non-standard API format, low limits (10K neurons/day)
- HuggingFace Inference: Small model limits on free tier, unreliable for LLM inference
- NVIDIA NIM: Credit-based, frequently overloaded

## Decision 4: Fallback Priority Ordering

**Decision**: Quality-tiered ordering: Groq → Mistral → Cerebras → OpenRouter → SambaNova → Ollama.

**Rationale**:
- **Groq first**: Fastest inference (custom LPU hardware), strong models (Llama 3.3 70B), generous limits
- **Mistral second**: Massive token limit (1B/month), good coding models (Codestral)
- **Cerebras third**: 1M tokens/day, very fast inference, large model (Qwen3 235B)
- **OpenRouter fourth**: Model aggregator with 27+ free models, auto-routing capability
- **SambaNova fifth**: Good models but lower RPM limits (10-20)
- **Ollama last**: Always available but limited by local GPU, smallest models

This ordering maximizes quality and speed for the first fallback attempt while preserving Ollama as the guaranteed-available last resort.

## Decision 5: Model Alias Strategy

**Decision**: Use `prefix/model-name` namespace pattern for all free providers. No unprefixed aliases.

**Rationale**: Free provider models must NOT overlap with existing OAuth aliases (e.g., `claude-sonnet-4-6`, `gemini-2.5-pro`). Using prefixes (`groq/llama-70b`, `mistral/codestral`, `ollama/qwen3`) prevents routing conflicts. Existing AI tools (Claude Code, OpenCode, OpenClaw) continue using their current model names and are unaffected — the prefixed free models are only accessible when ProxyPilot's internal routing decides to fall back.

**Note**: ProxyPilot's `openai-compatibility` section with `prefix` field handles this natively. Clients requesting `claude-sonnet-4-6` will never accidentally route to `groq/llama-70b`.

**Alternatives considered**:
- Unprefixed aliases: Risk collision with OAuth model names, confusing in logs
- Single generic alias (e.g., `fallback`): Loses model-specific routing control

## Decision 6: Ollama Integration Specifics

**Decision**: Use Ollama's OpenAI-compatible endpoint at `localhost:11434/v1` with dummy API key `"ollama"`.

**Rationale**: Ollama supports the OpenAI `/v1/chat/completions` endpoint natively. ProxyPilot auto-detects localhost upstreams and bypasses authentication, but the `api-key` field is required by the config schema. The string `"ollama"` is a safe dummy value that Ollama ignores.

Currently pulled models: `gemma3:12b`, `qwen2.5-coder:7b`, `qwen3:14b`, `qwen3.5:27b`. Best candidate for fallback: `qwen3.5:27b` (largest, best quality for coding).

## Decision 7: Grafana Dashboard Extension

**Decision**: Add a new "Fallback Providers" row to the existing ProxyPilot dashboard with 3 panels.

**Rationale**: The existing dashboard (`states/configs/grafana-dashboard-proxypilot.json`) uses Loki queries filtered on `syslog_identifier="proxypilot"`. ProxyPilot logs include provider names in request routing entries. New panels:
1. **Fallback Activation** (stat): Count of requests routed to free providers (log pattern match)
2. **Provider Error Rates** (timeseries): Per-provider 4xx/5xx counts over time
3. **Ollama Fallback** (stat): Count of requests that reached the Ollama last-resort tier

All panels use the same Loki datasource and `syslog_identifier="proxypilot"` filter — no new infrastructure needed.

## Decision 8: gopass Secret Structure

**Decision**: One gopass entry per provider under `api/` prefix.

**Rationale**: Follows existing pattern (`api/proxypilot-local`, `api/anthropic`, `api/proxypilot-management`). New entries:

| gopass path | Provider | Contents |
|-------------|----------|----------|
| `api/groq` | Groq | API key from console.groq.com |
| `api/mistral` | Mistral | API key from console.mistral.ai |
| `api/cerebras` | Cerebras | API key from cloud.cerebras.ai |
| `api/openrouter` | OpenRouter | API key from openrouter.ai/keys |
| `api/sambanova` | SambaNova | API key from cloud.sambanova.ai |

No gopass entry needed for Ollama (local, no auth).

## Decision 9: Emergency-Only Activation Mechanism

**Decision**: Rely on ProxyPilot's native model routing — free providers are only reachable via prefixed model names. The AI tools themselves don't know about free providers.

**Rationale**: ProxyPilot routes based on model name. When a client requests `claude-sonnet-4-6`, ProxyPilot tries the OAuth route. If it fails (after `request-retry: 3` attempts), ProxyPilot returns an error to the client. The *client tool* (Claude Code, OpenCode) would need to be configured to retry with a fallback model name.

**Critical insight**: ProxyPilot v0.3.0-dev-0.40 does NOT have native cross-provider fallback (i.e., "if model X on provider A fails, try model Y on provider B"). It does round-robin across API keys *within* a provider, and retries *within* the matched route. But it doesn't cascade to a different provider's model on failure.

**Implication**: The fallback mechanism needs to be implemented at the *client configuration level* — each AI tool needs a fallback model configured. OR, we use ProxyPilot's alias pooling: map the same alias to multiple upstream models across providers, so ProxyPilot round-robins across them.

**Revised approach**: Use alias pooling — configure multiple upstream models with the same alias across different `openai-compatibility` entries. When one fails, ProxyPilot's retry mechanism tries the next. Example:
```yaml
# In Groq entry:
models:
  - name: "llama-3.3-70b-versatile"
    alias: "fallback-large"
# In Mistral entry:
models:
  - name: "mistral-small-latest"
    alias: "fallback-large"
```

This makes `fallback-large` round-robin across Groq and Mistral transparently. The AI tools can be configured with `fallback-large` as their fallback model.
