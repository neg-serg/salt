# NotebookLM Setup Guide

## Overview

NotebookLM is Google's AI-powered research assistant that lets you upload
documents (PDFs, Google Docs, web pages, audio, YouTube) and ask questions
grounded in those sources. It generates summaries, FAQs, study guides, and
notably **Audio Overviews** (podcast-style conversations about your material).

It is a **web-only service** (no desktop app, no CLI, no package in repos/AUR).

## Access

| Detail | Value |
|---|---|
| URL | `https://notebooklm.google.com` |
| Auth | Google account |
| Pricing | Free tier available; NotebookLM Plus via Google One AI Premium ($20/mo) |
| API | None (no public API as of 2026-03) |

## Key Capabilities

- **Source grounding** — all answers cite uploaded sources, reducing hallucination
- **Audio Overviews** — generates two-host podcast conversations from sources
- **Multi-source notebooks** — up to 50 sources per notebook (PDF, Docs, Slides, web, YouTube, audio)
- **Interactive Q&A** — chat with your sources, get inline citations
- **Study guides / FAQs / Timelines** — auto-generated structured summaries
- **Source type support**: PDF, Google Docs/Slides, web URLs, YouTube, audio files, copied text, .md/.txt

## Limitations

- Web-only, no offline access
- No API for programmatic use
- Sources limited to ~500k words per notebook
- Audio Overviews: English-only generation (can summarize non-English sources)
- No export of generated audio to external platforms
- Data stored in Google Cloud (privacy consideration for sensitive documents)

## Use Cases for This Project

### RAG Knowledge Base Enrichment
NotebookLM can serve as an **interactive research layer** before ingesting
documentation into the local RAG stack (docs-rag / code-rag / LanceDB):

1. Upload reference docs (Salt docs, Hyprland wiki, tool manuals) into a notebook
2. Use NotebookLM to explore, ask questions, identify key sections
3. Feed curated URLs into `docs_sources.yaml` for permanent local indexing

### Podcast-Style Overviews
Generate Audio Overviews of complex documentation before diving into
implementation — useful for architecture reviews or learning new tools.

## Integration with Local RAG Stack

This project already has a docs ingestion pipeline:

| Component | Role |
|---|---|
| `docs-import` | CLI to ingest web pages, man pages, local markdown into LanceDB |
| `docs_sources.yaml` | Registry of documentation sources (URLs, depth, tags) |
| `llama-embed` | Local embedding server (Qwen3-Embedding-8B, port 11435) |
| `code-rag` MCP | Hybrid text+code search over indexed project |
| Qdrant MCP | Vector search (collection: `salt-project`) |

**Workflow**: NotebookLM (interactive exploration) -> identify valuable docs ->
add to `docs_sources.yaml` -> `docs-import` (permanent local RAG).

## Desktop Access Options

Since there is no native app, the closest options are:

### Option A: Zen Browser Pinned Tab
Pin `notebooklm.google.com` as a permanent tab in Zen Browser.
Lightweight, no extra dependencies.

### Option B: Chromium PWA (recommended for app-like experience)
```bash
# Install chromium (if not present)
sudo pacman -S chromium

# Launch and install as PWA:
# 1. Open https://notebooklm.google.com in Chromium
# 2. Menu (⋮) → "Install NotebookLM..."
# 3. Creates .desktop entry, launches in its own window
```

### Option C: Webapp Manager (AUR)
```bash
paru -S webapp-manager
# Create a web app shortcut for notebooklm.google.com
# Uses Firefox/Chromium profile isolation
```

## See Also

- [docs-rag spec](../specs/023-external-docs-rag/spec.md) — local documentation RAG pipeline
- [docs_sources.yaml](../states/data/docs_sources.yaml) — documentation source registry
