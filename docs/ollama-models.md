# Ollama Model Selection Guide

## Overview

Models are defined in `states/data/ollama.yaml` and pulled automatically
by `ollama.sls`. Each model must occupy a **unique niche** — if model B
from the same family is strictly better than model A at similar resource
cost, model A is a duplicate and should be removed.

## Selection Criteria

A model earns its place by being unique in **at least one** dimension:

| Dimension | Example |
|-----------|---------|
| Training family | Qwen vs Mistral vs BigCode vs Google — different data, different strengths |
| Architecture | MoE (sparse activation) vs Dense — different speed/quality tradeoffs |
| Context window | 16K vs 128K vs 256K — determines how much code fits in a single prompt |
| Language coverage | 17 languages vs 600+ — matters for rare/niche languages |
| Size class | ~4GB (fast local) vs ~19GB (quality) — different hardware tiers |
| Specialization | FIM completion vs agentic coding vs general reasoning |

## Current Models

### General-purpose

| Model | Size | Niche |
|-------|------|-------|
| `gemma3:12b` | ~8GB | Google; vision+text multimodal, best general <15B |
| `qwen3:14b` | ~9GB | Alibaba; thinking mode, strong reasoning |
| `qwen3.5:27b` | ~17GB | Alibaba; newest general-purpose, best <30B |

### Code-specialized

| Model | Size | Architecture | Context | Niche |
|-------|------|-------------|---------|-------|
| `qwen2.5-coder:7b` | ~4GB | Dense | 32K | Lightweight FIM/completion, fast inference |
| `qwen3-coder:30b` | ~19GB | MoE (3.3B active) | 256K | Best code quality, agentic workflows |
| `deepcoder:14b` | ~9GB | Dense | 128K | O3-mini level reasoning, fully open-source |
| `deepseek-coder-v2:16b` | ~9GB | MoE | 160K | GPT-4 class on code tasks |
| `codestral:22b` | ~13GB | Dense | 32K | Mistral family, different training data |
| `starcoder2:15b` | ~9GB | Dense | 16K | 600+ languages (The Stack v2), best for rare languages |

### Why these and not others

Each code model above has a unique combination of family + architecture + context
that no other model in the list covers:

- **qwen2.5-coder:7b** — only lightweight (~4GB) code model; nothing else runs this fast
- **qwen3-coder:30b** — MoE with only 3.3B active params means near-7B inference speed at 30B quality; 256K context is the largest in the list
- **deepcoder:14b** — dense 14B with 128K context; fills the mid-size dense slot between 7B and 22B
- **deepseek-coder-v2:16b** — MoE architecture from DeepSeek family (different training data than Qwen); 160K context
- **codestral:22b** — Mistral family (French lab, different training methodology); the only non-Chinese/non-US code model
- **starcoder2:15b** — BigCode consortium (open governance); 600+ languages from The Stack v2; only model optimized for rare/low-resource languages (Julia, Lua, R, Perl, etc.)

## Excluded Models (superseded)

These models were considered but excluded because a model already in the
list is strictly better in the same niche:

| Model | Superseded by | Reason |
|-------|---------------|--------|
| `deepseek-coder:6.7b` | `deepseek-coder-v2:16b` | Same family, v2 is newer and better at similar resource cost (MoE) |
| `codellama:7b` | `qwen2.5-coder:7b` | Same size class, Qwen wins on all code benchmarks |
| `codegemma:7b` | `gemma3:12b` | Same Google family, Gemma3 is newer and more capable |

## Adding a New Model

Before adding a model, check:

1. **Is the niche already covered?** Check the table above — if an existing
   model covers the same family + size class + architecture, the new model
   is likely a duplicate.
2. **Does it supersede an existing model?** If a new model from the same
   family is strictly better, replace the old one and move it to the
   "Excluded" section.
3. **Add a comment** in `ollama.yaml` on the same line explaining the
   unique niche (family, architecture, context, specialization).

## Storage

Models are stored on `/mnt/one/ollama/models`. Current total for code
models: ~63GB. General-purpose models add ~34GB. Total: ~97GB.

## Applying Changes

```bash
just apply ollama
```
