# Quickstart: Code-RAG Integration

**Phase 1 output** | **Date**: 2026-03-08

## Prerequisites

1. llama_embed service running (`systemctl status llama-embed`)
2. `~/src/code-rag` source directory exists
3. Salt apply completed (`just`)

## After Salt Apply

The `code_rag` state installs code-rag via pipx. Two CLI commands become available:

```bash
# Verify installation
code-rag-index --help
code-rag-search --help
```

## Index the Salt Project

```bash
# Index only the salt project
code-rag-index --project salt

# Index all projects under ~/src/
code-rag-index

# Force full re-index (ignore incremental state)
code-rag-index --project salt --force
```

First indexing takes 1-5 minutes depending on corpus size and embedding throughput. Subsequent runs skip unchanged files.

## Search

```bash
# Natural language search
code-rag-search "how to install packages with macros"

# Filter by language
code-rag-search "retry logic" --language yaml

# Filter by chunk kind
code-rag-search "service management" --kind function

# Filter by project
code-rag-search "GPU acceleration" --project salt

# Limit results
code-rag-search "systemd unit" --limit 5

# Hide code previews (metadata only)
code-rag-search "embedding" --no-text
```

## MCP Server (for AI agents)

The MCP server is configured in `.mcp.json`. AI agents (Claude Code) can use it automatically. To test manually:

```bash
# Start MCP server directly (for debugging)
python -m code_rag.server
```

Available MCP tools: `search_code`, `list_projects`, `reindex`.

## Updating code-rag

After modifying `~/src/code-rag` source:

```bash
# Reinstall to pick up changes
pipx install ~/src/code-rag --force
```

Or re-run Salt apply (the state will re-install if the binary is missing).

## Troubleshooting

**"Connection refused" on indexing**: Ensure llama_embed is running:
```bash
systemctl status llama-embed
curl http://127.0.0.1:11435/health
```

**No results for a known file**: Check if the file type is supported:
```bash
code-rag-search "" --project salt --language yaml  # List all yaml chunks
```

**Stale results after file changes**: Run incremental re-index:
```bash
code-rag-index --project salt
```
