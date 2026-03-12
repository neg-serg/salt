# Image Generation Provider Roster

Data-driven image generation with free AI providers and priority-based failover.

## Overview

The image generation roster follows the same pattern as `free_providers.yaml` for text AI:
- Providers defined in `states/data/image_providers.yaml`
- API keys resolved from gopass with AWK fallback
- Config rendered by Salt to `~/.config/image-gen/providers.yaml`
- `gen-image` CLI wrapper reads config and calls providers directly

## Providers

| Provider | API Type | Free Tier | Priority |
|----------|----------|-----------|----------|
| Together AI | OpenAI-compatible | $100 credits + 3mo FLUX.1-schnell | 1 |
| Hugging Face | Custom HF Inference | ~few hundred req/hr | 2 |
| Cloudflare Workers AI | Custom REST | 100k req/day | 3 |
| Local ComfyUI | Custom workflow | Unlimited (local GPU) | 5 |

## Setup

### 1. Seed API keys

```bash
# Seed keys interactively (skips existing)
scripts/bootstrap-image-providers.sh

# Check which keys exist
scripts/bootstrap-image-providers.sh --check
```

Or manually:

```bash
gopass insert api/together-ai    # https://api.together.xyz/settings/api-keys
gopass insert api/huggingface    # https://huggingface.co/settings/tokens
gopass insert api/cloudflare-ai  # https://dash.cloudflare.com/profile/api-tokens
```

### 2. Apply Salt state

```bash
just apply image_generation
```

### 3. Generate images

```bash
gen-image "a cat sitting on a rainbow"
gen-image "cyberpunk cityscape" --model flux-quality
gen-image "mountain landscape" --size 1024x768 --output ~/pic/landscape.png
```

## Model Aliases

Aliases pool the same capability across providers for failover:

| Alias | Description | Providers |
|-------|-------------|-----------|
| `flux-fast` | Fast FLUX generation | Together AI, Hugging Face, Cloudflare, ComfyUI |
| `flux-quality` | High-quality FLUX | Together AI, Hugging Face |
| `sdxl` | Stable Diffusion XL | Together AI, Hugging Face, Cloudflare, ComfyUI |

## Adding a Provider

1. Edit `states/data/image_providers.yaml`:

```yaml
  - name: "new-provider"          # unique name
    base_url: "https://api.example.com/v1"
    api_type: "openai"            # openai | huggingface | cloudflare | comfyui
    gopass_key: "api/new-provider"
    priority: 4                   # unique priority (1=highest)
    models:
      - name: "model-id"
        alias: "flux-fast"        # shared alias for failover pooling
```

2. Seed the API key:

```bash
gopass insert api/new-provider
```

3. Apply:

```bash
just apply image_generation
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `gen-image: command not found` | Run `just apply image_generation` or `chezmoi apply` |
| `config not found` | Run `just apply image_generation` |
| All providers fail | Check `scripts/bootstrap-image-providers.sh --check` |
| Cloudflare 403 | Set `account_id` in `image_providers.yaml` |
| ComfyUI timeout | Ensure ComfyUI is running on port 8188 |

## Files

| File | Purpose |
|------|---------|
| `states/data/image_providers.yaml` | Provider roster (edit this) |
| `states/configs/image-gen-providers.yaml.j2` | Config template |
| `states/image_generation.sls` | Salt state |
| `scripts/bootstrap-image-providers.sh` | API key seeding |
| `dotfiles/dot_local/bin/executable_gen-image` | CLI wrapper |
| `~/.config/image-gen/providers.yaml` | Rendered config (don't edit) |
