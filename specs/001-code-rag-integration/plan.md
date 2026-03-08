# Implementation Plan: Code-RAG Integration

**Branch**: `001-code-rag-integration` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-code-rag-integration/spec.md`

## Summary

Integrate the existing `~/src/code-rag` Python project into the salt configuration management system as an installable package. This involves: (1) a new Salt state file `code_rag.sls` that installs code-rag via pipx from local source, (2) an MCP server entry in `.mcp.json` for AI agent access, and (3) wiring into the existing `llama_embed` embedding service. No systemd services or deployment infrastructure — CLI-only.

## Technical Context

**Language/Version**: Python 3.12+ (code-rag), Jinja2/YAML (Salt states)
**Primary Dependencies**: tree-sitter-language-pack, lancedb, mcp[cli], httpx (all Python, managed by pipx)
**Storage**: LanceDB (embedded Arrow-based vector DB, local `.lancedb/` directory)
**Testing**: Manual verification via `just` (Salt render) + CLI smoke test (`code-rag-index --help`)
**Target Platform**: CachyOS (Arch-based) Linux workstation
**Project Type**: Configuration state (Salt .sls) + CLI tool integration
**Performance Goals**: Search <5s, incremental re-index <10s on unchanged corpus
**Constraints**: No systemd services for code-rag, no network access during install (local source), existing llama_embed on port 11435
**Scale/Scope**: ~12K chunks across ~7 projects, single user, single machine

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | PASS | Install guarded by `creates: ~/.local/bin/code-rag-index`. No unguarded `cmd.run` states. |
| II. Network Resilience | PASS | No network access needed — installs from local source `~/src/code-rag`. pipx resolves PyPI deps, so retry still applies. |
| III. Secrets Isolation | PASS | No secrets involved. code-rag uses no API keys or auth tokens. |
| IV. Macro-First | PASS | `pip_pkg` macro covers pipx install with guards/retry. Custom `cmd.run` not needed. |
| V. Minimal Change | PASS | One new `.sls` file, one `.mcp.json` entry, one include line. No refactoring. |
| VI. Convention Adherence | PASS | State ID: `code_rag_install`. Commit: `[code-rag]`. No shell scripts added. |
| VII. Verification Gate | PASS | `just` will be run before completion. |
| VIII. CI Gate | PASS | No CI currently configured for salt repo, but `just` serves as local equivalent. |

No violations. No complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/001-code-rag-integration/
├── plan.md              # This file
├── research.md          # Phase 0: installation method research
├── data-model.md        # Phase 1: entity model
├── quickstart.md        # Phase 1: usage guide
├── contracts/           # Phase 1: MCP tool contracts
│   └── mcp-tools.md
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
states/
├── code_rag.sls              # NEW: Salt state for code-rag installation
└── system_description.sls    # MODIFIED: add `- code_rag` to include list

.mcp.json                     # MODIFIED: add code-rag MCP server entry
```

**Structure Decision**: No new directories needed. One state file following the existing pattern (each `.sls` owns a domain). MCP config goes into the existing `.mcp.json`. The code-rag Python project itself is not modified — it's consumed as-is from `~/src/code-rag`.
