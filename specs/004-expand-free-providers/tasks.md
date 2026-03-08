# Tasks: Expand Free Fallback Provider Pool

**Input**: Design documents from `/specs/004-expand-free-providers/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested. Manual verification via `curl` and `just` per quickstart.md.

**Scope change**: SiliconFlow signup failed (verification code not delivered). Removed from implementation. DeepSeek remains as optional provider entry in data file. Feature delivers infrastructure readiness — DeepSeek activates whenever operator provisions the gopass key.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Data Definition

**Purpose**: Add DeepSeek optional entry to the data file. Update Grafana. SiliconFlow excluded (signup failed).

- [x] T001 Add DeepSeek optional provider entry (priority 4) with 2 models to `states/data/free_providers.yaml` per data-model.md: `deepseek-chat` (fallback-code), `deepseek-reasoner` (fallback-large). Update comment header to document DeepSeek as optional, SiliconFlow as excluded
- [x] T002 Renumber Ollama priority from 4 to 5 in `states/data/free_providers.yaml` and update comment header with new provider list and alias pooling counts
- [x] T003 [P] Add DeepSeek error rate target to the Provider Error Rates timeseries panel (id: 52) in `states/configs/grafana-dashboard-proxypilot.json`. Add deepseek to Fallback Activation stat panel regex
- [x] T004 Run `just` to verify Salt renders successfully with the updated data file and Grafana dashboard

**Checkpoint**: Data file has 5 providers (4 existing + 1 new optional). Grafana dashboard updated. Salt renders cleanly.

---

## Phase 2: US1+US3 — DeepSeek Registration + Zero-Cost Verification (Priority: P1)

**Goal**: Register DeepSeek (optional) in ProxyPilot and verify the expanded fallback chain works.

**Status**: BLOCKED — requires manual `gopass insert api/deepseek` by operator. DeepSeek is optional; system functions correctly without it.

### Implementation for User Story 1+3

- [ ] T005 [US1+US3] MANUAL (optional): Store API key for DeepSeek in gopass: `gopass insert api/deepseek`. Sign up at https://platform.deepseek.com (email/Google login). Skip if not using DeepSeek
- [ ] T006 [US1+US3] Run `scripts/bootstrap-free-providers.sh` to seed ProxyPilot config with new provider key. Verify DeepSeek shows "OK" in output
- [ ] T007 [US1+US3] Run `just` to deploy updated config, then `systemctl --user restart proxypilot`. Verify ProxyPilot startup log shows increased OpenAI-compat count (5 with DeepSeek)
- [ ] T008 [US1+US3] Verify DeepSeek responds: `curl` request to `http://127.0.0.1:8317/v1/chat/completions` with model `fallback-code` — should show `deepseek-chat` in round-robin alongside OpenRouter models
- [ ] T009 [US1+US3] Verify existing providers unaffected: confirm Groq, Cerebras, OpenRouter, Ollama, and paid routes (claude-sonnet-4-6) still work correctly

**Checkpoint**: DeepSeek responds if key provisioned. All existing routes unchanged.

---

## Phase 3: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates and final verification

- [x] T010 [P] Update `docs/proxypilot-free-fallback.md` with DeepSeek: add to provider table, alias coverage table, secrets table, signup URLs section. Document SiliconFlow as excluded (signup failed). Note: SiliconFlow can be revisited later
- [x] T011 [P] Update `docs/proxypilot-free-fallback.ru.md` with corresponding Russian translations
- [x] T012 [P] Update `docs/secrets-scheme.md` and `docs/secrets-scheme.ru.md` to include new gopass path (`api/deepseek`)
- [x] T013 Run final `just` to confirm full Salt render passes with all changes (Verification Gate, Constitution VII)

**Checkpoint**: All documentation reflects current provider pool. Salt renders cleanly. Feature complete (DeepSeek activates on key provisioning).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Data Definition (Phase 1)**: No dependencies — COMPLETE
- **US1+US3 (Phase 2)**: Depends on Phase 1 + gopass secret provisioned — BLOCKED on manual key
- **Polish (Phase 3)**: Depends on Phase 1 only — can proceed now

### Parallel Opportunities

- T010, T011, T012 (docs) can all run in parallel (different files)

---

## Implementation Strategy

### Current Approach

1. ~~Complete Phase 1: Add data entries + Grafana queries~~ DONE
2. Phase 2: BLOCKED on manual DeepSeek key provisioning (optional — system works without it)
3. Complete Phase 3: Documentation + final verification
4. Commit and close feature

### What Changed

- SiliconFlow removed: signup verification code not delivered (Chinese phone/email issue)
- Feature reduced to: DeepSeek optional entry + Grafana monitoring + documentation
- US2 (alias redundancy) dropped: without SiliconFlow, no new mandatory providers to improve alias coverage
- DeepSeek activates automatically whenever operator provisions `api/deepseek` gopass key

---

## Notes

- SiliconFlow excluded due to signup failure — documented for future retry
- DeepSeek is optional throughout — activates on gopass key provisioning
- No code changes required — all tasks are data file edits, Grafana JSON edits, or documentation updates
- The existing bootstrap script and Salt template handle the new provider automatically
- `just` must pass at every checkpoint (Constitution VII: Verification Gate)
