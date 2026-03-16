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
| `qwen3.5:27b` | ~17GB | Alibaba; newest general-purpose, best <30B |
| `qwen3:32b` | ~20GB | Alibaba; dense 32B, top quality general |
| `qwen3:8b-q8_0` | ~9GB | Alibaba; fast general+thinking mode, hybrid CoT |
| `llama3.3:70b-instruct-q5_K_M` | ~50GB | Meta; 128K ctx, best instruction following (RAM offload) |
| `qwen3:235b-a22b` | ~142GB | Alibaba; MoE 235B (22B active), minimal censorship (GPU+RAM offload) |

### Reasoning

| Model | Size | Niche |
|-------|------|-------|
| `qwq:32b` | ~20GB | Alibaba; dedicated reasoning/math, extended CoT |

### Vision

| Model | Size | Niche |
|-------|------|-------|
| `qwen2.5vl:7b-q8_0` | ~8GB | Alibaba; OCR+semantic, charts/docs/screenshots |

### Uncensored (abliterated)

| Model | Size | Niche |
|-------|------|-------|
| `huihui_ai/qwen3-abliterated:30b-a3b` | ~17GB | huihui-ai; uncensored general MoE 3B active |
| `huihui_ai/qwen3-coder-abliterated` | ~17GB | huihui-ai; uncensored coding MoE 3B active |
| `huihui_ai/qwen3.5-abliterated:35b-a3b` | ~19GB | huihui-ai; uncensored newest MoE 3B active |

### Code-specialized

| Model | Size | Architecture | Context | Niche |
|-------|------|-------------|---------|-------|
| `qwen2.5-coder:7b-instruct-q6_K` | ~6GB | Dense | 32K | Lightweight FIM/completion, Q6_K quality |
| `qwen3-coder:30b` | ~18GB | MoE (3.3B active) | 256K | Best code quality, agentic workflows |
| `deepcoder:14b` | ~9GB | Dense | 128K | O3-mini level reasoning, fully open-source |
| `devstral:24b` | ~19GB | Dense | 128K | Mistral; agentic coding, SWE-bench top tier |

### Why these and not others

Each code model above has a unique combination of family + architecture + context
that no other model in the list covers:

- **qwen2.5-coder:7b-instruct-q6_K** — only lightweight (~6GB) code model; nothing else runs this fast with Q6_K quality
- **qwen3-coder:30b** — MoE with only 3.3B active params means near-7B inference speed at 30B quality; 256K context is the largest in the list
- **deepcoder:14b** — dense 14B with 128K context; fills the mid-size dense slot between 7B and 24B
- **devstral:24b** — Mistral family (French lab, different training methodology); SWE-bench top tier, agentic coding

## Excluded Models (superseded)

These models were considered but excluded because a model already in the
list is strictly better in the same niche:

| Model | Superseded by | Reason |
|-------|---------------|--------|
| `deepseek-coder:6.7b` | `deepcoder:14b` | Same niche (DeepSeek code), deepcoder is newer with 128K context |
| `deepseek-coder-v2:16b` | `qwen3-coder:30b` | Superseded: same MoE niche, qwen3-coder better on all benchmarks |
| `codellama:7b` | `qwen2.5-coder:7b-instruct-q6_K` | Same size class, Qwen wins on all code benchmarks |
| `codegemma:7b` | `qwen2.5-coder:7b-instruct-q6_K` | Same size class, Qwen is more capable |
| `gemma3:12b` | `qwen3.5:27b` | No tool calling support in Ollama API |
| `gemma3:27b` | `qwen3.5:27b` | No tool calling support in Ollama API |
| `starcoder2:15b` | `qwen3-coder:30b` | Superseded on all code benchmarks |
| `codestral:22b` | `devstral:24b` | Same Mistral family, devstral is newer and agentic |
| `mistral-nemo` | `qwen3:8b-q8_0` | Better quality at same size |
| `qwen3:14b` | `qwen3.5:27b` | Same family, newer and stronger |
| `llama3.1:70b` | `llama3.3:70b-instruct-q5_K_M` | Same size, llama3.3 better quality |

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

Models are stored on `/mnt/one/ollama/models`. See `ollama list` for
current sizes. Total varies with model roster; expect ~300GB+ with all
models including the 70B and 235B variants.

## Applying Changes

```bash
just apply ollama
```
