# Data Model: Code-RAG Integration

**Phase 1 output** | **Date**: 2026-03-08

## Entities

### Chunk (existing — defined by code-rag)

The atomic unit of indexed content. Extracted from source files via tree-sitter AST parsing.

| Field | Type | Description |
|-------|------|-------------|
| vector | float32[4096] | Qwen3-Embedding vector |
| text | string | Raw chunk content |
| file_path | string | Absolute path to source file |
| project | string | Project name (directory under `~/src/`) |
| language | string | File language (python, yaml, bash, etc.) |
| kind | string | Chunk type: function, class, preamble, fragment, file, etc. |
| name | string | Definition name or `anon_<line>` |
| start_line | int32 | First line number in source file |
| end_line | int32 | Last line number in source file |

**Storage**: LanceDB table `code_chunks` in `.lancedb/` directory (Apache Arrow columnar format).

### Index State (existing — defined by code-rag)

Per-file tracking for incremental indexing.

| Field | Type | Description |
|-------|------|-------------|
| file_path | string (key) | Absolute path to tracked file |
| hash | string (value) | `{mtime_ns}:{file_size}` — fast change detection |

**Storage**: JSON file `.index_state.json` alongside `.lancedb/`.

### Project (derived — computed at query time)

Not stored explicitly. Derived by aggregating chunks grouped by `project` field.

| Field | Type | Description |
|-------|------|-------------|
| name | string | Directory name under `~/src/` |
| chunk_count | int | Total chunks in this project |
| file_count | int | Unique files indexed |
| languages | list[string] | Languages present |

## Relationships

```text
Project 1──* Chunk (via project field)
File    1──* Chunk (via file_path field)
```

No foreign keys — LanceDB is schemaless beyond the Arrow schema. Relationships are implicit via string field matching.

## Salt State Entities (new)

These are the Salt/Jinja entities created by this feature:

### code_rag.sls State

| State ID | Type | Purpose |
|----------|------|---------|
| `install_code_rag` | cmd.run (via `pip_pkg`) | Install code-rag from local source |

Single state. No config files, no services, no directories to manage.

### .mcp.json Entry

| Field | Value |
|-------|-------|
| key | `code-rag` |
| type | `stdio` |
| command | `python` |
| args | `["-m", "code_rag.server"]` |
