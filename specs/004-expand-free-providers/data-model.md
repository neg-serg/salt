# Data Model: Expand Free Fallback Provider Pool

## Provider Entry Schema

Unchanged from 003-proxypilot-free-fallback. Each provider entry in `states/data/free_providers.yaml`:

```yaml
- name: "<provider-id>"           # Unique identifier, used in Grafana queries and logs
  base_url: "<openai-compat-url>" # OpenAI-compatible base URL (no trailing /v1 if provider includes it)
  gopass_key: "<gopass-path>"     # gopass secret path (cloud providers)
  # OR
  dummy_key: "<static-key>"      # Static key (local providers like Ollama)
  priority: <int>                 # Lower = tried first in round-robin rotation
  models:
    - name: "<model-id>"          # Provider-specific model identifier (exact API string)
      alias: "<fallback-alias>"   # Shared alias for cross-provider failover
```

## New Provider Entries

### SiliconFlow (priority 4)

```yaml
- name: "siliconflow"
  base_url: "https://api.siliconflow.cn/v1"
  gopass_key: "api/siliconflow"
  priority: 4
  models:
    - name: "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"
      alias: "fallback-large"
    - name: "Qwen/Qwen2.5-Coder-7B-Instruct"
      alias: "fallback-code"
    - name: "Qwen/Qwen3-8B"
      alias: "fallback-medium"
    - name: "Qwen/Qwen3.5-4B"
      alias: "fallback-small"
```

### DeepSeek (priority 5, optional)

```yaml
- name: "deepseek"
  base_url: "https://api.deepseek.com"
  gopass_key: "api/deepseek"
  priority: 5
  models:
    - name: "deepseek-chat"
      alias: "fallback-code"
    - name: "deepseek-reasoner"
      alias: "fallback-large"
```

## Updated Priority Map

| Priority | Provider | Status |
|----------|----------|--------|
| 1 | Groq | Existing |
| 2 | Cerebras | Existing |
| 3 | OpenRouter | Existing |
| 4 | SiliconFlow | **New** |
| 5 | DeepSeek | **New (optional)** |
| 6 | Ollama | Existing (renumbered from 4) |

## Updated Alias Coverage

| Alias | Before (003) | After (004) | Cloud Providers |
|-------|-------------|-------------|-----------------|
| fallback-large | Groq, Cerebras, OpenRouter, Ollama | + SiliconFlow, DeepSeek* | 5 cloud (4 mandatory + 1 optional) |
| fallback-code | OpenRouter, Ollama | + SiliconFlow, DeepSeek* | 3 cloud (2 mandatory + 1 optional) |
| fallback-medium | Groq, Ollama | + SiliconFlow | 2 cloud |
| fallback-small | Cerebras (only!) | + SiliconFlow | 2 cloud |

*DeepSeek entries only active if operator provisions `api/deepseek` gopass key.

## Validation Rules

- `name` must be unique across all providers
- `base_url` must be a valid URL (HTTPS for cloud, HTTP for localhost)
- `gopass_key` or `dummy_key` required (mutually exclusive)
- `priority` must be unique integer, ascending
- Each `models[].alias` must be one of: `fallback-large`, `fallback-code`, `fallback-medium`, `fallback-small`
- Model `name` must be the exact string accepted by the provider's API
