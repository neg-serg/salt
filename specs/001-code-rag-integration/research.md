# Research: Code-RAG Integration

**Phase 0 output** | **Date**: 2026-03-08

## R1: Python Package Installation Method

**Decision**: Use `pip_pkg` macro with `pkg=~/src/code-rag` parameter for pipx-based install from local source.

**Rationale**: The `pip_pkg` macro in `_macros_install.jinja` wraps `pipx install <pkg>`. pipx supports local paths and editable installs natively. The macro automatically provides:
- Idempotency guard: `creates: ~/.local/bin/code-rag-index`
- Retry: `{attempts: 3, interval: 10}` (for PyPI dependency resolution)
- Parallel: `True`
- State ID: `install_code_rag_index`

However, `pip_pkg` generates one state per binary. code-rag produces two binaries (`code-rag-index`, `code-rag-search`) from a single package install. The macro guards on a single `creates:` path, so we guard on `code-rag-index` (the primary binary). Both binaries are installed atomically by pipx.

**Alternatives considered**:
- `pip install -e` in a venv: More complex, requires managing a venv directory. pipx already creates isolated environments.
- `uv tool install`: Used for `aider-chat` in this project, but requires specific Python version pinning. code-rag works with system Python 3.12+.
- Custom `cmd.run`: Unnecessary — `pip_pkg` macro covers this use case.

**Open question resolved**: pipx handles local source paths. `pipx install ~/src/code-rag` installs the package and creates entry points in `~/.local/bin/`. To update after source changes, user runs `pipx install ~/src/code-rag --force`.

## R2: Embedding Server Integration

**Decision**: Reuse existing `llama_embed` service on port 11435. No configuration changes needed in code-rag — its default `http://127.0.0.1:11435/v1/embeddings` URL matches the existing service.

**Rationale**: The `llama_embed.sls` state already deploys:
- llama.cpp server with Qwen3-Embedding-8B (Q5_K_M quantization)
- Port 11435, bound to 127.0.0.1
- Health check at `/health`, 90s timeout
- Vulkan GPU acceleration, 8192 context window
- Systemd service with auto-restart

code-rag's `embedder.py` defaults to `http://127.0.0.1:11435/v1/embeddings` — exact match. No environment variables or configuration needed.

**Alternatives considered**:
- Ollama embeddings (port 11434): Would require code changes to use Ollama API format instead of OpenAI-compatible `/v1/embeddings`.
- Separate embedding server instance: Violates FR-009 and wastes GPU memory.

## R3: MCP Server Configuration

**Decision**: Add code-rag MCP server entry to `.mcp.json` using stdio transport with `python -m code_rag.server` command.

**Rationale**: The existing `.mcp.json` already has 31 MCP server entries. The pattern is consistent: stdio transport, command + args + env. code-rag's `server.py` uses FastMCP and is designed to run as a stdio process.

The MCP server needs to know where the LanceDB database is stored. code-rag defaults to `.lancedb/` relative to the project root, but when run as an MCP server from any directory, the DB path should be absolute. We'll pass it via environment variable or let it use the default discovery.

**Alternatives considered**:
- Systemd user service for MCP: Overkill for stdio-based MCP, violates FR-012.
- SSE transport: Not needed — Claude Code uses stdio for all local MCP servers.

## R4: Feature Gating

**Decision**: No feature gate (`host.features.*`) needed. code-rag is always enabled when the state file is included.

**Rationale**: code-rag has an `onlyif: test -d ~/src/code-rag` guard on the install state. If the source directory doesn't exist, the state silently skips. This is simpler than adding a feature flag to `hosts.yaml` for a tool that's only meaningful when its source is present.

**Alternatives considered**:
- `host.features.code_rag` gate: Adds indirection. The source directory presence is the natural gate — if you have code-rag source, you want it installed.

## R5: State File Placement

**Decision**: New `states/code_rag.sls` file, included in `system_description.sls` after `llama_embed`.

**Rationale**: Each `.sls` file owns a domain. code-rag is a standalone tool, not part of installers (it's not a simple binary download) or any existing domain. Placing after `llama_embed` in the include list reflects the dependency: embedding server should be available before code-rag is installed.

**Alternatives considered**:
- Add to `installers.sls`: code-rag is more than a simple CLI tool — it has MCP integration and depends on llama_embed. Deserves its own state.
- Add to `ollama.sls`: Wrong domain — code-rag doesn't use Ollama.
