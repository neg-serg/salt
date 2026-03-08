# MCP Tool Contracts: Code-RAG

**Phase 1 output** | **Date**: 2026-03-08

## Transport

- **Protocol**: MCP (Model Context Protocol) over stdio
- **Server**: `python -m code_rag.server` (FastMCP)
- **Configuration**: `.mcp.json` entry at repository root

## Tools

### search_code

Search indexed code using hybrid vector + full-text search.

**Parameters**:

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| query | string | yes | — | Natural language query or code snippet |
| project | string | no | null | Filter by project name |
| language | string | no | null | Filter by language (e.g., "python", "yaml") |
| limit | integer | no | 10 | Maximum results to return |

**Returns**: Formatted text with search results, each containing:
- `project/file_path:start_line-end_line`
- `[language] kind: name`
- `score: <float>`
- Code preview (max 10 lines)

**Error cases**:
- No index exists → returns message suggesting `reindex`
- Embedding server unreachable → returns connection error
- No results found → returns empty result message

### list_projects

List all indexed projects with statistics.

**Parameters**: None.

**Returns**: Formatted text listing each project with:
- Project name
- Total chunks
- Unique files
- Languages present

### reindex

Re-index one or all projects.

**Parameters**:

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| project | string | no | null | Specific project to re-index (null = all) |
| force | boolean | no | false | Force full re-index ignoring incremental state |

**Returns**: Summary of indexing operation:
- Projects processed
- Chunks created/updated/deleted
- Time elapsed

**Side effects**: Modifies `.lancedb/` and `.index_state.json` on disk.
