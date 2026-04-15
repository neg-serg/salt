# Ollama Models

## Source of Truth

Model definitions live in `states/data/ollama.yaml`. That file is the authoritative roster — add, remove, or comment models there only.

## Selection Criterion

Each model must occupy a **unique niche** — unique in at least one dimension: training family, architecture (MoE vs Dense), context window, size class, or specialization (vision, reasoning, code, uncensored). If a model from the same family is strictly better at similar resource cost, the weaker one is a duplicate and should be removed.

## Adding or Removing Models

1. Check whether the niche is already covered by an existing model.
2. If a new model supersedes an existing one, replace it and leave a commented-out line in `ollama.yaml` noting what it replaced.
3. Add an inline comment in `ollama.yaml` explaining the unique niche.

## Storage

Models are stored on `/mnt/one/ollama/models`. Run `ollama list` for current sizes; expect ~300GB+ with the full roster.

## Applying Changes

```bash
just apply ollama
```
