# Data Model: ProxyPilot Free Model Fallback

**Date**: 2026-03-08 | **Branch**: `003-proxypilot-free-fallback`

## Entity: Free Provider

Defined in `states/data/free_providers.yaml`. Consumed by Salt Jinja template `states/configs/proxypilot.yaml.j2`.

### Attributes

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Internal identifier (appears in logs, must be unique) |
| `base_url` | string | yes | Provider's OpenAI-compatible base URL |
| `gopass_key` | string | no | gopass secret path for API key (omit for local providers like Ollama) |
| `dummy_key` | string | no | Static dummy API key (for providers that don't require auth, e.g., Ollama). Mutually exclusive with `gopass_key`. |
| `priority` | integer | yes | Fallback order (1 = first tried, higher = later). Used for documentation and tiering. |
| `models` | list | yes | Model name mappings |
| `models[].name` | string | yes | Upstream model ID at the provider |
| `models[].alias` | string | yes | Alias exposed to ProxyPilot clients. Shared aliases across providers enable round-robin failover. |

### Schema (YAML)

```yaml
# states/data/free_providers.yaml
providers:
  - name: "groq"
    base_url: "https://api.groq.com/openai/v1"
    gopass_key: "api/groq"
    priority: 1
    models:
      - name: "llama-3.3-70b-versatile"
        alias: "fallback-large"
      - name: "qwen/qwen3-32b"
        alias: "fallback-medium"

  - name: "mistral"
    base_url: "https://api.mistral.ai/v1"
    gopass_key: "api/mistral"
    priority: 2
    models:
      - name: "codestral-latest"
        alias: "fallback-code"
      - name: "mistral-small-latest"
        alias: "fallback-large"

  - name: "cerebras"
    base_url: "https://api.cerebras.ai/v1"
    gopass_key: "api/cerebras"
    priority: 3
    models:
      - name: "qwen-3-235b-a22b-instruct"
        alias: "fallback-large"
      - name: "llama3.1-8b"
        alias: "fallback-small"

  - name: "openrouter"
    base_url: "https://openrouter.ai/api/v1"
    gopass_key: "api/openrouter"
    priority: 4
    models:
      - name: "qwen/qwen3-coder-480b-a35b:free"
        alias: "fallback-code"
      - name: "openrouter/auto"
        alias: "fallback-large"

  - name: "sambanova"
    base_url: "https://api.sambanova.ai/v1"
    gopass_key: "api/sambanova"
    priority: 5
    models:
      - name: "Meta-Llama-3.3-70B-Instruct"
        alias: "fallback-large"
      - name: "Meta-Llama-3.1-8B-Instruct"
        alias: "fallback-small"

  - name: "ollama"
    base_url: "http://localhost:11434/v1"
    dummy_key: "ollama"
    priority: 6
    models:
      - name: "qwen3.5:27b"
        alias: "fallback-large"
      - name: "qwen2.5-coder:7b"
        alias: "fallback-code"
      - name: "qwen3:14b"
        alias: "fallback-medium"
```

### Alias Pooling Strategy

Shared aliases enable cross-provider failover. When a request targets `fallback-large`, ProxyPilot round-robins across all providers that expose that alias:

| Alias | Providers | Purpose |
|-------|-----------|---------|
| `fallback-large` | Groq (Llama 70B), Mistral (Small), Cerebras (Qwen3 235B), OpenRouter (auto), SambaNova (Llama 70B), Ollama (Qwen3.5 27B) | General-purpose large model fallback |
| `fallback-code` | Mistral (Codestral), OpenRouter (Qwen3 Coder 480B), Ollama (Qwen2.5 Coder 7B) | Code-specialized fallback |
| `fallback-medium` | Groq (Qwen3 32B), Ollama (Qwen3 14B) | Mid-tier fallback |
| `fallback-small` | Cerebras (Llama 8B), SambaNova (Llama 8B) | Fast small model fallback |

## Entity: Fallback Chain

Not a persisted entity — this is a runtime concept in ProxyPilot's routing. The chain is implicit from the alias pooling:

```
Request for "fallback-large"
  → Groq llama-3.3-70b-versatile
  → Mistral mistral-small-latest
  → Cerebras qwen-3-235b-a22b-instruct
  → OpenRouter openrouter/auto
  → SambaNova Meta-Llama-3.3-70B-Instruct
  → Ollama qwen3.5:27b
  → ERROR (all providers exhausted)
```

Order is determined by ProxyPilot's round-robin across credentials. The `priority` field in the data file is for documentation and future explicit ordering.

## Entity: gopass Secret

| Path | Provider | Created by |
|------|----------|-----------|
| `api/groq` | Groq | Manual signup at console.groq.com |
| `api/mistral` | Mistral | Manual signup at console.mistral.ai |
| `api/cerebras` | Cerebras | Manual signup at cloud.cerebras.ai |
| `api/openrouter` | OpenRouter | Manual signup at openrouter.ai |
| `api/sambanova` | SambaNova | Manual signup at cloud.sambanova.ai |

## Jinja Template Rendering

The Salt template `states/configs/proxypilot.yaml.j2` will receive the free providers data as Jinja context and render the `openai-compatibility` section dynamically:

```jinja
{# Render free fallback providers #}
{% if free_providers %}
openai-compatibility:
{% for p in free_providers %}
  - name: "{{ p.name }}"
    base-url: "{{ p.base_url }}"
    api-key-entries:
      - api-key: "{{ p.api_key }}"
    models:
{% for m in p.models %}
      - name: "{{ m.name }}"
        alias: "{{ m.alias }}"
{% endfor %}
{% endfor %}
{% endif %}
```

The Salt state (`opencode.sls`) resolves `api_key` from gopass before passing to the template:
```jinja
{% for p in free_providers_data.providers %}
  {% set key = gopass_secret(p.gopass_key, '') if p.gopass_key is defined else p.dummy_key %}
  {# Build resolved provider list with actual API key values #}
{% endfor %}
```
