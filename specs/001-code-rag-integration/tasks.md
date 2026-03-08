# Tasks: Code-RAG Integration

**Input**: Design documents from `/specs/001-code-rag-integration/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/mcp-tools.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No project initialization needed — all changes go into existing files. This phase validates prerequisites.

- [x] T001 Verify `~/src/code-rag` source exists and contains `pyproject.toml` with entry points
- [x] T002 Verify llama_embed service is running on port 11435 (`curl http://127.0.0.1:11435/health`)

**Checkpoint**: Prerequisites confirmed — implementation can begin.

---

## Phase 2: Foundational (Salt State)

**Purpose**: Create the Salt state file that all user stories depend on.

- [x] T003 Create Salt state file `states/code_rag.sls` with `pip_pkg` macro call: import `_imports.jinja` and `_macros_install.jinja`, call `pip_pkg('code_rag_index', pkg=home ~ '/src/code-rag', bin='code-rag-index')` wrapped in `onlyif: test -d {{ home }}/src/code-rag`
- [x] T004 Add `- code_rag` to include list in `states/system_description.sls` after `llama_embed` line
- [x] T005 Run `just` to verify Salt renders successfully with the new state (Verification Gate)

**Checkpoint**: Salt state renders cleanly. `code_rag.sls` is included in the state tree.

---

## Phase 3: User Story 1 — Install code-rag (Priority: P1) MVP

**Goal**: `code-rag-index` and `code-rag-search` are available in `$PATH` after Salt apply.

**Independent Test**: Run `code-rag-index --help` — should print usage information.

### Implementation for User Story 1

- [x] T006 [US1] Apply Salt state locally: run `sudo salt-call state.apply code_rag` to install code-rag via pipx
- [x] T007 [US1] Verify both binaries exist: `test -x ~/.local/bin/code-rag-index && test -x ~/.local/bin/code-rag-search`
- [x] T008 [US1] Verify idempotency: re-run `sudo salt-call state.apply code_rag` and confirm the install state reports "already satisfied" / no changes

**Checkpoint**: US1 complete — code-rag CLI tools installed and idempotent.

---

## Phase 4: User Story 2 — Index the salt corpus (Priority: P1)

**Goal**: Salt project files are indexed with AST-aware chunks across 6+ file types.

**Independent Test**: Run `code-rag-index --project salt` and verify chunks are created.

### Implementation for User Story 2

- [x] T009 [US2] Run `code-rag-index --project salt` and verify successful completion
- [x] T010 [US2] Verify chunks cover at least 6 file types (`.sls`, `.jinja`, `.sh`, `.py`, `.lua`, `.md`) by running `code-rag-search "" --project salt` and inspecting language tags in results

**Checkpoint**: US2 complete — salt corpus indexed with multi-language chunks.

---

## Phase 5: User Story 3 — Search across the corpus (Priority: P1)

**Goal**: Hybrid search returns relevant results from the salt corpus.

**Independent Test**: Run `code-rag-search "macro for installing packages"` and verify results include `_macros_pkg.jinja`.

### Implementation for User Story 3

- [x] T011 [US3] Run `code-rag-search "retry logic for network"` and verify results include chunks from `_macros_install.jinja` or network-related states
- [x] T012 [US3] Run `code-rag-search "systemd user service" --language yaml` and verify filtered results
- [x] T013 [US3] Verify incremental index: re-run `code-rag-index --project salt` on unchanged corpus and confirm <10s completion

**Checkpoint**: US3 complete — search returns relevant, filtered results. Incremental indexing works.

---

## Phase 6: User Story 4 — MCP server for AI agents (Priority: P2)

**Goal**: code-rag MCP server is configured in `.mcp.json` and accessible to Claude Code.

**Independent Test**: Verify the MCP server entry exists and the server process starts.

### Implementation for User Story 4

- [x] T014 [US4] Add `code-rag` MCP server entry to `.mcp.json` with stdio transport: `{"type": "stdio", "command": "python", "args": ["-m", "code_rag.server"]}`
- [x] T015 [US4] Verify MCP server starts without errors: `python -m code_rag.server` (should listen on stdio without crashing)

**Checkpoint**: US4 complete — MCP server configured for AI agent access.

---

## Phase 7: User Story 5 — Embedding server integration (Priority: P2)

**Goal**: code-rag uses the existing llama_embed service without separate infrastructure.

**Independent Test**: Verify code-rag's default embedding URL matches the running service.

### Implementation for User Story 5

- [x] T016 [US5] Verify code-rag default URL `http://127.0.0.1:11435/v1/embeddings` matches running llama_embed service by confirming indexing produces valid embeddings (already validated by T009)
- [x] T017 [US5] Verify no additional systemd services were created for code-rag: `systemctl list-unit-files | grep -i code.rag` should return empty

**Checkpoint**: US5 complete — code-rag integrates with existing embedding infrastructure.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and verification gate.

- [x] T018 Run `just` to confirm full Salt render passes with all changes (Verification Gate)
- [x] T019 Validate quickstart.md scenarios: run through `specs/001-code-rag-integration/quickstart.md` steps end-to-end

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — prerequisite checks only
- **Foundational (Phase 2)**: Depends on Phase 1 — creates the Salt state
- **US1 (Phase 3)**: Depends on Phase 2 — applies the state to install code-rag
- **US2 (Phase 4)**: Depends on US1 (code-rag must be installed to index)
- **US3 (Phase 5)**: Depends on US2 (index must exist to search)
- **US4 (Phase 6)**: Depends on Phase 2 only — MCP config is independent of install
- **US5 (Phase 7)**: Depends on US2 (embedding integration verified through indexing)
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (Install)**: Blocks US2, US3, US5 — cannot index/search without installation
- **US2 (Index)**: Blocks US3, US5 — cannot search without index, cannot verify embeddings without indexing
- **US3 (Search)**: Terminal — no other stories depend on it
- **US4 (MCP)**: Independent of US1-US3 (config file change only, no runtime dependency)
- **US5 (Embedding)**: Terminal — verification story, no other stories depend on it

### Parallel Opportunities

- T001 and T002 can run in parallel (independent prerequisite checks)
- T003 and T014 can run in parallel (different files: `code_rag.sls` vs `.mcp.json`)
- US4 (MCP config) can run in parallel with US1-US3 (independent file)

---

## Parallel Example: Foundational + MCP

```
# These can run in parallel (different files):
T003: Create states/code_rag.sls
T014: Add code-rag entry to .mcp.json
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Phase 1: Verify prerequisites (T001-T002)
2. Phase 2: Create state file + include (T003-T005)
3. Phase 3: Install and verify (T006-T008)
4. **STOP and VALIDATE**: `code-rag-index --help` works

### Full Feature

1. MVP (above)
2. Phase 4: Index salt corpus (T009-T010)
3. Phase 5: Verify search (T011-T013)
4. Phase 6: MCP config (T014-T015) — can run parallel with Phase 4-5
5. Phase 7: Verify embedding integration (T016-T017)
6. Phase 8: Final validation (T018-T019)

---

## Notes

- All Salt state changes are in 2 files: `states/code_rag.sls` (new) and `states/system_description.sls` (one include line)
- MCP config is 1 file: `.mcp.json` (one new entry)
- No code changes to `~/src/code-rag` — consumed as-is
- Commit style: `[code-rag] description`
- US2 and US3 have no Salt implementation tasks — they validate the installed tool works correctly
- US5 is a verification-only story — no implementation, just confirmation that existing infrastructure works
