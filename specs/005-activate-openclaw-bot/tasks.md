# Tasks: Activate OpenClaw Telegram Bot

**Input**: Design documents from `/specs/005-activate-openclaw-bot/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Not requested — verification is via `just` (Salt apply) and manual Telegram testing.

**Organization**: Tasks grouped by user story. US1 and US2 share the same implementation (config template change enables both), so they are combined in Phase 2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

```text
states/
├── configs/openclaw.json.j2          # Config template
├── units/user/openclaw-gateway.service  # Systemd unit
└── openclaw_agent.sls                # Salt state
docs/
├── openclaw-setup.md                 # Setup guide (English)
└── openclaw-setup.ru.md              # Setup guide (Russian)
```

---

## Phase 1: Foundational (Config Template + Salt State)

**Purpose**: Core config and state changes that enable all user stories

**⚠️ CRITICAL**: No verification or service work can begin until this phase is complete

- [x] T001 Replace Anthropic provider with ProxyPilot provider in `states/configs/openclaw.json.j2`: remove `anthropic` provider block (baseUrl `https://api.anthropic.com`, api `anthropic-messages`), add `proxypilot` provider block (baseUrl `http://127.0.0.1:8317`, apiKey from `proxy_key`, api `openai-completions`), add models `claude-sonnet-4-6` and `claude-opus-4-6` (200k context, 16k output), update `agents.defaults.model.primary` to `proxypilot/claude-sonnet-4-6`, update fallbacks to `["proxypilot/claude-opus-4-6"]`
- [x] T002 [P] Add config migration state and clean up variables in `states/openclaw_agent.sls`: add `openclaw_config_migrate` state (cmd.run `rm -f` with `onlyif: test -f` + `unless: grep -q 'openai-completions'`) before `openclaw_config`, require `openclaw_config_dir`, add `openclaw_config_migrate` to `openclaw_config` require list; remove `_anthropic_key` variable, remove `anthropic_key` from template context

**Checkpoint**: Config template and Salt state updated — ready for deployment and verification

---

## Phase 2: US1 + US2 — Bot Responds via ProxyPilot (Priority: P1) 🎯 MVP

**Goal**: The bot receives Telegram messages and responds using Claude Sonnet 4.6 routed through ProxyPilot

**Independent Test**: Run `just` to apply Salt, then send a message to the Telegram bot and verify it responds within 60 seconds

### Implementation for US1 + US2

- [x] T003 [US1] Run `just` to apply Salt states and verify rendering succeeds without errors (SC-004)
- [x] T004 [US2] Verify deployed config has ProxyPilot provider: run `grep 'openai-completions' ~/.openclaw/openclaw.json` and `openclaw models list` to confirm models are routable
- [x] T005 [US1] Verify gateway service is running: `systemctl --user status openclaw-gateway` and check logs with `journalctl --user -u openclaw-gateway --no-pager -n 20` for Telegram channel connection
- [x] T006 [US1] Send test message to Telegram bot and verify AI response within 60 seconds (SC-001); check ProxyPilot logs `journalctl --user -u proxypilot --no-pager -n 20` for matching routed request (SC-002)
- [x] T007 [US2] Send 10 consecutive messages to verify OAuth routing stability — no authentication failures or silent drops (SC-006)

**Checkpoint**: Bot responds to Telegram messages via ProxyPilot — MVP complete

---

## Phase 3: US3 — Service Reliability (Priority: P2)

**Goal**: OpenClaw gateway starts after ProxyPilot and recovers from failures automatically

**Independent Test**: Restart `openclaw-gateway` service, verify it comes up after `proxypilot.service`. Stop ProxyPilot, verify OpenClaw logs errors but doesn't crash.

### Implementation for US3

- [x] T008 [US3] Add ProxyPilot dependency to `states/units/user/openclaw-gateway.service`: add `Wants=proxypilot.service` to `[Unit]` section, append `proxypilot.service` to `After=` line
- [x] T009 [US3] Run `just` to apply updated unit file, then verify startup ordering: `systemctl --user show openclaw-gateway.service -p Wants,After` should include `proxypilot.service`

**Checkpoint**: Service dependency declared — OpenClaw starts after ProxyPilot on boot (SC-005)

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and final verification

- [x] T010 Update `docs/openclaw-setup.md` to reflect ProxyPilot-only provider (remove Anthropic references, document ProxyPilot as sole provider)
- [x] T011 [P] Update `docs/openclaw-setup.ru.md` with matching Russian translation of provider changes
- [x] T012 Run `just` for final Salt verification to confirm all states render cleanly (SC-004)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: No dependencies — start immediately
- **US1+US2 (Phase 2)**: Depends on Phase 1 completion — BLOCKS on config template + Salt state
- **US3 (Phase 3)**: Depends on Phase 1 completion — can run in parallel with Phase 2
- **Polish (Phase 4)**: Depends on Phases 2 and 3 being complete

### User Story Dependencies

- **US1 + US2 (P1)**: Combined — same implementation (config template change). Can start after Phase 1.
- **US3 (P2)**: Independent of US1/US2 — different file (`openclaw-gateway.service`). Can start after Phase 1 in parallel with Phase 2.

### Within Each Phase

- Phase 1: T001 and T002 are [P] — different files, can run in parallel
- Phase 2: T003 → T004 → T005 → T006 → T007 — sequential verification chain
- Phase 3: T008 → T009 — sequential (edit then verify)
- Phase 4: T010 and T011 are [P] — different files

### Parallel Opportunities

```text
Phase 1 (parallel):
  T001 (openclaw.json.j2) ─┐
  T002 (openclaw_agent.sls) ┘─→ Phase 1 complete

Phase 2 + Phase 3 (parallel after Phase 1):
  T003 → T004 → T005 → T006 → T007  (US1+US2 sequential verification)
  T008 → T009                        (US3 can run alongside)

Phase 4 (parallel):
  T010 (docs EN) ─┐
  T011 (docs RU)  ┘─→ T012 (final `just`)
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2)

1. Complete Phase 1: Edit config template + Salt state (T001, T002)
2. Complete Phase 2: Apply Salt, verify bot responds (T003–T007)
3. **STOP and VALIDATE**: Bot responds to Telegram messages via ProxyPilot
4. This is the MVP — the bot works

### Incremental Delivery

1. Phase 1 + Phase 2 → Bot responds (MVP!)
2. Phase 3 → Service reliability (startup ordering)
3. Phase 4 → Documentation updated, final verification

---

## Notes

- T001 and T002 are the only code-editing tasks — everything else is verification or docs
- The migration state in T002 is the key to making `replace: False` work with the provider switch
- T003–T007 are sequential verification steps that require system access (Salt apply, service status, Telegram)
- US1 and US2 are combined because the config template change simultaneously enables both
- Total implementation effort: ~30 lines changed across 3 files
