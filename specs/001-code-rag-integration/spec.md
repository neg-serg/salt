# Feature Specification: Code-RAG Integration

**Feature Branch**: `001-code-rag-integration`
**Created**: 2026-03-08
**Status**: Draft
**Input**: Integrate ~/src/code-rag project into salt as an installable package for hybrid text+code RAG with embeddings over the existing corpus. No deployment yet.

## User Scenarios & Testing

### User Story 1 - Install code-rag as a local package (Priority: P1)

The user installs code-rag from the local source at `~/src/code-rag` so that `code-rag-index` and `code-rag-search` CLI commands are available system-wide. Installation follows the Salt project's macro-first approach and is idempotent — re-running Salt does not reinstall if the package is already present.

**Why this priority**: Without installation, no other functionality is available. This is the foundation for all subsequent stories.

**Independent Test**: Run `code-rag-index --help` and `code-rag-search --help` after Salt apply — both commands respond with usage information.

**Acceptance Scenarios**:

1. **Given** code-rag source exists at `~/src/code-rag`, **When** Salt apply runs, **Then** `code-rag-index` and `code-rag-search` are available in `$PATH` and executable.
2. **Given** code-rag is already installed, **When** Salt apply runs again, **Then** the install state is skipped (idempotency guard fires).
3. **Given** code-rag source is missing, **When** Salt apply runs, **Then** the state fails gracefully without breaking other states.

---

### User Story 2 - Index the salt project corpus (Priority: P1)

The user indexes the salt project's hybrid corpus (Salt states, Jinja templates, shell scripts, Python, Lua, YAML, Markdown) by running `code-rag-index`. The indexer uses tree-sitter AST-aware chunking to produce semantically meaningful chunks from code and text files alike.

**Why this priority**: Indexing is the prerequisite for search. Without an index, there is no RAG capability. Equal priority with installation since both are needed for minimum viable functionality.

**Independent Test**: Run `code-rag-index --project salt` and verify chunks are created in the LanceDB database covering `.sls`, `.jinja`, `.sh`, `.lua`, `.py`, and `.md` files.

**Acceptance Scenarios**:

1. **Given** code-rag is installed and the embedding server is running, **When** user runs `code-rag-index --project salt`, **Then** the salt project is indexed with chunks for all supported file types.
2. **Given** the salt project was previously indexed and no files changed, **When** `code-rag-index --project salt` runs again, **Then** no re-indexing occurs (incremental index via file hash).
3. **Given** a `.sls` file was modified, **When** indexer runs, **Then** only the changed file's chunks are re-embedded and updated.

---

### User Story 3 - Search across the hybrid corpus (Priority: P1)

The user searches the indexed corpus using natural language queries or code snippets. The hybrid search (vector + full-text with RRF reranking) returns relevant results from both code and configuration files, with file paths, line numbers, language tags, and chunk kinds.

**Why this priority**: Search is the core RAG capability — the reason code-rag exists. Combined with US1 and US2, this completes the minimum viable feature.

**Independent Test**: Run `code-rag-search "macro for installing packages"` and verify results include relevant Salt macros from `_macros_pkg.jinja` with scores, line numbers, and code previews.

**Acceptance Scenarios**:

1. **Given** the salt corpus is indexed, **When** user runs `code-rag-search "retry logic for network"`, **Then** results include chunks from `_macros_install.jinja` and/or network-related states with relevance scores.
2. **Given** the corpus is indexed, **When** user searches with `--language yaml --kind function`, **Then** results are filtered to YAML files containing function-like definitions.
3. **Given** the corpus is indexed, **When** user searches with `--project salt`, **Then** only salt project chunks are returned.

---

### User Story 4 - MCP server for AI agent integration (Priority: P2)

The code-rag MCP server is available for AI agents (Claude Code, opencode) to perform semantic search over the corpus. The MCP server exposes `search_code`, `list_projects`, and `reindex` tools via the Model Context Protocol.

**Why this priority**: MCP integration amplifies the RAG's value by making it available to AI coding agents, but the core CLI functionality (US1-US3) must work first.

**Independent Test**: Start the MCP server and call `search_code` with a query — verify it returns structured results.

**Acceptance Scenarios**:

1. **Given** the corpus is indexed and MCP server is configured, **When** an AI agent calls `search_code("systemd user service macro")`, **Then** relevant chunks from `_macros_service.jinja` are returned with metadata.
2. **Given** MCP server is running, **When** agent calls `list_projects()`, **Then** all indexed projects with chunk counts are returned.

---

### User Story 5 - Embedding server dependency (Priority: P2)

The llama.cpp embedding server (Qwen3-Embedding) required by code-rag is already managed by the salt project via `llama_embed.sls`. The code-rag installation integrates with this existing service without duplicating infrastructure.

**Why this priority**: The embedding server is a prerequisite for indexing and search, but it already exists in the salt project. This story ensures proper integration rather than creating a separate instance.

**Independent Test**: Verify `code-rag-index` successfully connects to the existing llama_embed service at `127.0.0.1:11435` and produces embeddings.

**Acceptance Scenarios**:

1. **Given** `llama_embed` service is running on port 11435, **When** code-rag indexes a project, **Then** embeddings are generated via the existing service without errors.
2. **Given** `llama_embed` service is not running, **When** code-rag attempts to index, **Then** a clear error message indicates the embedding server is unavailable.

---

### Edge Cases

- What happens when indexing a file with unsupported encoding (binary, non-UTF8)?
- How does the system handle very large files (>512 KB) in the salt corpus?
- What happens when the LanceDB database is corrupted or missing?
- How does incremental indexing handle renamed files (old path deleted, new path added)?
- What happens when the embedding server is overloaded or returns errors mid-batch?
- How does search behave when the index is empty (no projects indexed yet)?

## Requirements

### Functional Requirements

- **FR-001**: System MUST install code-rag as a Python package from `~/src/code-rag` source, making `code-rag-index` and `code-rag-search` CLI commands available.
- **FR-002**: Installation state MUST be idempotent — guarded by presence of installed CLI binaries.
- **FR-003**: System MUST support indexing all file types present in the salt corpus: `.sls`, `.jinja`, `.jinja2`, `.sh`, `.zsh`, `.bash`, `.py`, `.lua`, `.yaml`, `.yml`, `.toml`, `.md`, `.conf`, `.service`.
- **FR-004**: Indexer MUST use AST-aware chunking (tree-sitter) for supported languages and fall back to line-based chunking for unsupported formats.
- **FR-005**: Indexer MUST support incremental indexing — only re-processing files that changed since the last run.
- **FR-006**: Search MUST combine vector similarity and full-text search using reciprocal rank fusion (RRF) reranking.
- **FR-007**: Search results MUST include: file path, line range, language, chunk kind, definition name, relevance score, and code preview.
- **FR-008**: Search MUST support filtering by project, language, and chunk kind.
- **FR-009**: System MUST use the existing llama_embed service (Qwen3-Embedding on port 11435) for embeddings — no separate embedding infrastructure.
- **FR-010**: MCP server MUST expose `search_code`, `list_projects`, and `reindex` tools for AI agent consumption.
- **FR-011**: LanceDB database MUST be stored locally — no external database dependencies.
- **FR-012**: System MUST NOT deploy services or systemd units for code-rag itself at this stage (indexing and search are manual CLI operations).

### Key Entities

- **Chunk**: A semantically meaningful unit of code or text extracted from a source file. Has: vector embedding (4096-dim), text content, file path, project name, language, kind (function/class/preamble/etc.), definition name, line range.
- **Project**: A source directory under `~/src/` that contains indexable files. Has: name, chunk count, file count, language distribution.
- **Index State**: Per-file hash tracking (mtime + size) for incremental indexing. Stored in `.index_state.json`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Both `code-rag-index` and `code-rag-search` commands are available and functional after a single Salt apply.
- **SC-002**: The salt project corpus indexes successfully, producing chunks for at least 6 different file types (`.sls`, `.jinja`, `.sh`, `.py`, `.lua`, `.md`).
- **SC-003**: A natural-language search query returns relevant results from the salt corpus within 5 seconds.
- **SC-004**: Re-running the indexer on an unchanged corpus completes in under 10 seconds (incremental skip).
- **SC-005**: The MCP server responds to `search_code` queries with structured results matching the CLI output quality.
- **SC-006**: No additional systemd services or deployment infrastructure are created for code-rag (CLI-only at this stage).

## Storage Backend Strategy

**Phase 1 (this feature)**: LanceDB — embedded, zero-infrastructure vector database with native hybrid search (vector + FTS + RRF reranking). Optimal for the current scale (~12K chunks) where the simplicity of a single `lancedb.connect(path)` call outweighs the ~5x QPS advantage of in-memory alternatives. Provides hybrid search without external dependencies.

**Phase 2 (future TODO)**: Evaluate FAISS as an alternative backend for pure vector search. FAISS achieves ~978 QPS vs LanceDB's ~178 QPS at 0.95 recall on 1M vectors, with sub-millisecond latency. If the corpus grows significantly (100K+ chunks) or if FTS proves unnecessary (vector-only search is sufficient), FAISS would be the faster choice. This would require implementing a storage abstraction layer and a separate FTS solution (e.g., Tantivy) for hybrid search.

## Assumptions

- The `~/src/code-rag` source repository is always available on the workstation (not pulled from remote during Salt apply).
- Python 3.12+ is already installed on the system (managed outside Salt).
- The llama_embed service (`llama_embed.sls`) is already functional and running Qwen3-Embedding on port 11435.
- LanceDB and tree-sitter-language-pack are installed as Python dependencies of the code-rag package (managed by pip, not pacman).
- The user will manually run `code-rag-index` when they want to update the index — no automatic/scheduled indexing at this stage.
- MCP server configuration for AI agents (Claude Code, opencode) will be handled by the user or in a follow-up feature — this spec covers making the server available, not configuring consumers.
