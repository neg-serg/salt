# Tasks: Expand Free Fallback Provider Pool

**Input**: Design documents from `/specs/004-expand-free-providers/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested. Manual verification via `curl` and `just` per quickstart.md.

**Organization**: US1 (add Chinese providers) and US3 (maintain zero-cost) are combined because US3 is a constraint on US1, not an independent deliverable. US2 (alias redundancy) is a verification phase that depends on US1 completion.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Data Definition

**Purpose**: Add new provider entries to the data file. No code changes — purely additive YAML.

- [ ] T001 Add SiliconFlow provider entry (priority 4) with 4 models to `states/data/free_providers.yaml` per data-model.md: `deepseek-ai/DeepSeek-R1-Distill-Qwen-7B` (fallback-large), `Qwen/Qwen2.5-Coder-7B-Instruct` (fallback-code), `Qwen/Qwen3-8B` (fallback-medium), `Qwen/Qwen3.5-4B` (fallback-small)
- [ ] T002 Add DeepSeek optional provider entry (priority 5) with 2 models to `states/data/free_providers.yaml` per data-model.md: `deepseek-chat` (fallback-code), `deepseek-reasoner` (fallback-large). Update comment header to document DeepSeek as optional
- [ ] T003 Renumber Ollama priority from 4 to 6 in `states/data/free_providers.yaml` and update comment header with new provider list and alias pooling counts
- [ ] T004 [P] Add SiliconFlow and DeepSeek error rate targets to the Provider Error Rates timeseries panel (id: 52) in `states/configs/grafana-dashboard-proxypilot.json`. Add both provider names to Fallback Activation stat panel regex
- [ ] T005 Run `just` to verify Salt renders successfully with the updated data file and Grafana dashboard

**Checkpoint**: Data file has 6 providers (4 existing + 2 new). Grafana dashboard updated. Salt renders cleanly.

---

## Phase 2: User Story 1+3 — Chinese Provider Registration + Zero-Cost Verification (Priority: P1)

**Goal**: Register SiliconFlow (mandatory) and DeepSeek (optional) in ProxyPilot and verify the expanded fallback chain works with zero monetary cost.

**Independent Test**: Store SiliconFlow gopass key, run bootstrap + just, then `curl` ProxyPilot with `fallback-small` and verify a SiliconFlow model responds.

### Implementation for User Story 1+3

- [ ] T006 [US1+US3] MANUAL: Store API key for SiliconFlow in gopass: `gopass insert api/siliconflow`. Sign up at https://cloud.siliconflow.cn/ (email/GitHub/Google OAuth)
- [ ] T007 [US1+US3] MANUAL (optional): Store API key for DeepSeek in gopass: `gopass insert api/deepseek`. Sign up at https://platform.deepseek.com (email/Google login). Skip if not using DeepSeek
- [ ] T008 [US1+US3] Run `scripts/bootstrap-free-providers.sh` to seed ProxyPilot config with new provider keys. Verify all providers show "OK" in output
- [ ] T009 [US1+US3] Run `just` to deploy updated config, then `systemctl --user restart proxypilot`. Verify ProxyPilot startup log shows increased OpenAI-compat count (5 or 6 depending on DeepSeek)
- [ ] T010 [US1+US3] Verify SiliconFlow responds: `curl` request to `http://127.0.0.1:8317/v1/chat/completions` with model `fallback-small` — should show `Qwen/Qwen3.5-4B` in round-robin alongside Cerebras `llama3.1-8b`
- [ ] T011 [P] [US1+US3] Verify DeepSeek responds (if key provisioned): `curl` request with model `fallback-code` — should show `deepseek-chat` in round-robin alongside OpenRouter and SiliconFlow models
- [ ] T012 [US1+US3] Verify existing providers unaffected: confirm Groq, Cerebras, OpenRouter, Ollama, and paid routes (claude-sonnet-4-6) still work correctly after expansion

**Checkpoint**: SiliconFlow responds through ProxyPilot. DeepSeek responds if key provisioned. All existing routes unchanged. System operates at zero monetary cost.

---

## Phase 3: User Story 2 — Alias Redundancy Verification (Priority: P2)

**Goal**: Confirm every `fallback-*` alias has at least 2 cloud providers after the expansion.

**Independent Test**: Send requests to each alias and verify responses come from different cloud providers (not just Ollama).

### Implementation for User Story 2

- [ ] T013 [US2] Verify alias coverage: for each of `fallback-large`, `fallback-code`, `fallback-medium`, `fallback-small`, send 5 requests and confirm at least 2 distinct cloud provider models appear in responses (SC-002)
- [ ] T014 [US2] Verify sanctions-resistant path: temporarily block all 3 US providers (Groq, Cerebras, OpenRouter) by invalidating their keys, confirm `fallback-large` still responds via SiliconFlow + Ollama (SC-003). Restore keys after test

**Checkpoint**: Every alias has 2+ cloud providers. Chinese providers serve requests when US providers are unavailable.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates and final verification

- [ ] T015 [P] Update `docs/proxypilot-free-fallback.md` with new providers: add SiliconFlow and DeepSeek to provider table, alias coverage table, secrets table, signup URLs section
- [ ] T016 [P] Update `docs/proxypilot-free-fallback.ru.md` with corresponding Russian translations
- [ ] T017 [P] Update `docs/secrets-scheme.md` and `docs/secrets-scheme.ru.md` to include new gopass paths (`api/siliconflow`, `api/deepseek`)
- [ ] T018 Run final `just` to confirm full Salt render passes with all changes (Verification Gate, Constitution VII)

**Checkpoint**: All documentation reflects expanded provider pool. Salt renders cleanly. Feature complete.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Data Definition (Phase 1)**: No dependencies — can start immediately
- **US1+US3 (Phase 2)**: Depends on Phase 1 + gopass secrets provisioned
- **US2 (Phase 3)**: Depends on Phase 2 (needs live providers to verify alias coverage)
- **Polish (Phase 4)**: Depends on Phase 2 (needs confirmed provider list for accurate docs)

### User Story Dependencies

- **US1+US3 (P1)**: Can start after Phase 1 — no dependencies on US2
- **US2 (P2)**: Can start after US1+US3 — needs live providers for coverage testing

### Within Each Phase

- Data file and Grafana dashboard (parallel, different files) before Salt apply
- gopass secrets before bootstrap script before deployment
- Deployment before verification

### Parallel Opportunities

- T004 (Grafana) can run in parallel with T001-T003 (different file)
- T011 (DeepSeek verify) can run in parallel with T010 (SiliconFlow verify)
- T015, T016, T017 (docs) can all run in parallel (different files)

---

## Implementation Strategy

### MVP First (Phase 1-2 Only)

1. Complete Phase 1: Add data entries + Grafana queries
2. Complete Phase 2: Provision keys + deploy + verify
3. **STOP and VALIDATE**: Test `fallback-small` — confirm SiliconFlow responds
4. System already has expanded coverage at this point

### Incremental Delivery

1. Data Definition → Config infrastructure ready
2. US1+US3 → SiliconFlow live, zero-cost confirmed (MVP!)
3. US2 → Alias redundancy verified
4. Polish → Documentation complete, final verification

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- DeepSeek is optional throughout — all tasks involving DeepSeek can be skipped
- No code changes required — all tasks are data file edits, Grafana JSON edits, or documentation updates
- The existing bootstrap script and Salt template handle new providers automatically
- `just` must pass at every checkpoint (Constitution VII: Verification Gate)
