# Tasks: ProxyPilot Free Model Fallback

**Input**: Design documents from `/specs/003-proxypilot-free-fallback/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Not explicitly requested. Manual verification via `curl` and `just` per quickstart.md.

**Organization**: Tasks are grouped by user story. US1 (fallback) and US2 (provider registration) are combined into a single phase because US2 is a prerequisite for US1 and they are co-equal P1.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Data Definition)

**Purpose**: Create the data-driven free provider definitions

- [x] T001 Create free provider data file with all 6 providers (5 cloud + Ollama) at `states/data/free_providers.yaml` per data-model.md schema. Include: name, base_url, gopass_key/dummy_key, priority, models with alias pooling (fallback-large, fallback-code, fallback-medium, fallback-small)

---

## Phase 2: Foundational (Salt Infrastructure)

**Purpose**: Modify Salt state and config template to consume the new data file. MUST complete before any user story verification.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T002 Modify `states/opencode.sls` to import `states/data/free_providers.yaml` via `import_yaml`, resolve each provider's API key using `gopass_secret()` macro (with empty-string fallback for missing keys), and pass the resolved provider list as Jinja context (`free_providers`) to the `proxypilot_config` file.managed state
- [x] T003 Modify `states/configs/proxypilot.yaml.j2` to render an `openai-compatibility` section from the `free_providers` Jinja context variable. For each provider: emit `name`, `base-url`, `api-key-entries` (single key), and `models` array with `name`/`alias` mappings. Wrap in `{% if free_providers %}` guard so the section is omitted when no providers are configured. Preserve all existing config sections unchanged (FR-007)
- [x] T004 Run `just` to verify Salt renders successfully with the new data file and template changes. Fix any Jinja rendering errors before proceeding

**Checkpoint**: Salt renders cleanly. ProxyPilot config template includes `openai-compatibility` section. No existing functionality broken.

---

## Phase 3: User Story 1+2 — Provider Registration & Fallback Chain (Priority: P1) MVP

**Goal**: Register 5 cloud free providers + Ollama in ProxyPilot config and verify the cascading fallback chain works end-to-end.

**Independent Test**: Store at least one gopass secret, run `just`, then `curl` ProxyPilot with a `fallback-large` model request and verify a response is returned.

### Implementation for User Story 1+2

- [ ] T005 [US1+US2] MANUAL: Store API keys in gopass for all 3 cloud providers: `gopass insert api/groq`, `gopass insert api/cerebras`, `gopass insert api/openrouter`. Then run `scripts/bootstrap-free-providers.sh` to seed ProxyPilot config. Document signup URLs in commit message per quickstart.md
- [ ] T006 [US1+US2] Run `just` to deploy the updated ProxyPilot config with all free providers injected. Verify `~/.config/proxypilot/config.yaml` contains the `openai-compatibility` section with all 4 providers (3 cloud + Ollama) and no plaintext gopass paths (FR-002)
- [ ] T007 [US1+US2] Verify ProxyPilot loads the new config: restart service (`systemctl --user restart proxypilot`), check `proxypilot -list-models` output includes fallback aliases (fallback-large, fallback-code, fallback-medium, fallback-small) alongside existing OAuth models
- [ ] T008 [P] [US1+US2] Verify each cloud provider independently responds via ProxyPilot: `curl` requests to `http://127.0.0.1:8317/v1/chat/completions` with model names `fallback-large`, `fallback-code`, `fallback-medium`, `fallback-small` — each should return a valid chat completion response within 30 seconds (SC-001)
- [ ] T009 [P] [US1+US2] Verify Ollama last-resort tier responds: `curl` request to ProxyPilot with an Ollama-specific model alias and confirm response comes from local Ollama (check response headers or model field in response)
- [ ] T010 [US1+US2] Verify alias pooling works: send multiple requests to `fallback-large` and confirm responses come from different providers (check response model field or ProxyPilot logs for round-robin evidence)
- [ ] T011 [US1+US2] Verify existing paid routes are unaffected (FR-007): confirm `claude-sonnet-4-6`, `gemini-2.5-pro`, and `openai/gpt-5-codex` aliases still route to their original OAuth providers, not to free fallback providers

**Checkpoint**: All 6 fallback providers respond through ProxyPilot. Alias pooling distributes requests across providers. Existing paid routes unchanged. MVP is functional.

---

## Phase 4: User Story 3 — Health Monitoring (Priority: P2)

**Goal**: Verify ProxyPilot's native health monitoring deprioritizes failed providers and recovers when they come back online.

**Independent Test**: Configure one provider with an invalid API key, send requests to a shared alias, and confirm ProxyPilot routes around the broken provider.

### Implementation for User Story 3

- [ ] T012 [US3] Verify ProxyPilot's existing retry mechanism handles provider failures: temporarily invalidate one provider's API key in gopass, re-deploy with `just`, send requests to `fallback-large`, and confirm responses come from remaining healthy providers (not the broken one)
- [ ] T013 [US3] Verify recovery: restore the provider's valid API key, re-deploy with `just`, and confirm the provider re-enters the routing pool on subsequent requests
- [ ] T014 [US3] Review and document ProxyPilot's health-related config params (`request-retry`, `max-retry-credentials`, `max-retry-interval`) in context of free provider fallback. Adjust values in `states/configs/proxypilot.yaml.j2` if testing reveals suboptimal behavior (e.g., too many retries on a dead provider before moving on)

**Checkpoint**: ProxyPilot routes around failed free providers and recovers when they come back. Retry/rotation config is tuned for fallback use case.

---

## Phase 5: User Story 4 — Model Quality Tiering (Priority: P3)

**Goal**: Verify the fallback chain respects quality ordering: larger/better models are tried before smaller ones.

**Independent Test**: Block all providers except the lowest-priority ones and confirm requests degrade through the expected quality tiers.

### Implementation for User Story 4

- [ ] T015 [US4] Verify quality tier ordering in `states/data/free_providers.yaml`: confirm `fallback-large` alias includes providers ordered by quality (Groq 70B → Cerebras 235B → OpenRouter auto → Ollama 27B). Adjust data file ordering if ProxyPilot respects declaration order for round-robin
- [ ] T016 [US4] Document the tiering strategy in a comment header in `states/data/free_providers.yaml` explaining the priority ordering rationale (Groq first for speed, Ollama last for guaranteed availability)

**Checkpoint**: Free providers are ordered by quality tier. Documentation explains the ordering.

---

## Phase 6: Observability (FR-011)

**Purpose**: Extend Grafana dashboard to expose free provider fallback metrics.

- [x] T017 [P] Add a "Fallback Providers" row to `states/configs/grafana-dashboard-proxypilot.json` with 3 new panels: (1) Fallback Activation stat panel — count of requests routed to free providers using Loki query on `syslog_identifier="proxypilot"` with provider name filter, (2) Provider Error Rates timeseries — per-provider 4xx/5xx counts over time, (3) Ollama Fallback stat panel — count of requests reaching the Ollama last-resort tier
- [ ] T018 Run `just` to deploy updated Grafana dashboard. Open Grafana at `http://127.0.0.1:3000`, navigate to ProxyPilot dashboard, verify the new "Fallback Providers" row appears with all 3 panels rendering (SC-006)

**Checkpoint**: Operator can see fallback activation status, per-provider error rates, and Ollama usage in Grafana dashboard.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, final verification, and cleanup

- [ ] T019 [P] Create `docs/proxypilot-free-fallback.md` documenting: provider signup URLs, gopass secret paths, fallback chain explanation, alias pooling strategy, how to add/remove providers (SC-003), troubleshooting guide
- [ ] T020 [P] Create `docs/proxypilot-free-fallback.ru.md` Russian translation of the documentation (convention: English primary, Russian `.ru.md` translation)
- [ ] T021 Run final `just` to confirm full Salt render passes with all changes (Verification Gate, Constitution VII). Capture clean apply log
- [ ] T022 Update `docs/secrets-scheme.md` and `docs/secrets-scheme.ru.md` to include the 3 new gopass paths (`api/groq`, `api/cerebras`, `api/openrouter`)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1+US2 (Phase 3)**: Depends on Phase 2 + gopass secrets provisioned
- **US3 (Phase 4)**: Depends on Phase 3 (needs working providers to test health monitoring)
- **US4 (Phase 5)**: Depends on Phase 3 (needs working providers to verify tiering)
- **Observability (Phase 6)**: Independent of Phases 3-5, depends only on Phase 2 (can run in parallel with US verification)
- **Polish (Phase 7)**: Depends on all previous phases

### User Story Dependencies

- **US1+US2 (P1)**: Can start after Foundational (Phase 2) — no dependencies on other stories
- **US3 (P2)**: Can start after US1+US2 — needs live providers to test health monitoring
- **US4 (P3)**: Can start after US1+US2 — needs live providers to verify ordering

### Within Each User Story

- Data file before Salt template before Salt state
- Salt apply before verification
- Each verification step confirms the previous implementation step

### Parallel Opportunities

- T008 and T009 can run in parallel (different provider verification targets)
- T017 (Grafana) can run in parallel with Phase 3-5 (independent file)
- T019 and T020 can run in parallel (different docs files)

---

## Parallel Example: Phase 3 Verification

```bash
# After T007 (config deployed), verify providers in parallel:
Task: T008 "Verify each cloud provider independently via curl"
Task: T009 "Verify Ollama last-resort tier via curl"
```

## Parallel Example: Phase 6+7

```bash
# Grafana dashboard and documentation are independent:
Task: T017 "Add Fallback Providers row to Grafana dashboard"
Task: T019 "Create English documentation"
Task: T020 "Create Russian documentation"
```

---

## Implementation Strategy

### MVP First (Phase 1-3 Only)

1. Complete Phase 1: Create `free_providers.yaml`
2. Complete Phase 2: Modify Salt state + template
3. Complete Phase 3: Provision gopass secrets + deploy + verify fallback
4. **STOP and VALIDATE**: Test `fallback-large` model via `curl` — confirm response from free provider
5. System is already usable as emergency fallback at this point

### Incremental Delivery

1. Setup + Foundational → Config infrastructure ready
2. US1+US2 → Fallback chain functional (MVP!)
3. US3 → Health monitoring verified
4. US4 → Quality tiering verified
5. Observability → Grafana dashboard extended
6. Polish → Documentation complete, final verification
7. Each phase adds confidence without breaking previous work

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- gopass secrets (T005) is a manual step — cannot be automated in Salt
- ProxyPilot's `openai-compatibility` section is additive — it does not affect existing OAuth routes
- Alias pooling (shared `fallback-*` aliases across providers) is the key mechanism for cross-provider failover
- The `just` command must pass at every checkpoint (Constitution VII: Verification Gate)
