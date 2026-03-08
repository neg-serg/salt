# Implementation Plan: Activate OpenClaw Telegram Bot

**Branch**: `005-activate-openclaw-bot` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-activate-openclaw-bot/spec.md`

## Summary

Activate the OpenClaw Telegram bot by switching its model provider from direct Anthropic API (which requires a paid key) to ProxyPilot (`127.0.0.1:8317`), which routes to Claude Sonnet 4.6 via OAuth and free providers. Three files need modification: the config template (swap provider), the systemd unit (add ProxyPilot dependency), and the Salt state (add config migration for existing installs).

## Technical Context

**Language/Version**: Jinja2/YAML (Salt states), JSON (OpenClaw config), INI (systemd unit)
**Primary Dependencies**: Salt, OpenClaw 2026.3.2 (npm), ProxyPilot 0.3.0-dev-0.40, gopass
**Storage**: JSON config file (`~/.openclaw/openclaw.json`)
**Testing**: `just` (Salt apply verification), manual Telegram message test, `openclaw models list`, `openclaw doctor`
**Target Platform**: CachyOS (Arch-based) Linux workstation
**Project Type**: Configuration management (Salt states + systemd)
**Performance Goals**: Bot response within 60 seconds, OAuth routing stable for 10+ consecutive requests
**Constraints**: ProxyPilot must be running, gopass secrets must be accessible (Yubikey), `replace: False` must be preserved after migration
**Scale/Scope**: Single user, 3 files modified, ~30 lines changed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | PASS | Migration state uses `onlyif` + `unless` guards; runs exactly once |
| II. Network Resilience | PASS | No new network states added; existing `retry`/`parallel` on npm install unchanged |
| III. Secrets Isolation | PASS | `proxy_key` already resolved via gopass fallback; `anthropic_key` removed (no longer needed) |
| IV. Macro-First | PASS | No new infrastructure patterns; config template and unit file are direct edits |
| V. Minimal Change | PASS | Only 3 files modified, no new abstractions, no speculative features |
| VI. Convention Adherence | PASS | Migration state ID follows `target_descriptor` pattern (`openclaw_config_migrate`); commit scope `[openclaw]` |
| VII. Verification Gate | PASS | `just` will be run after changes |
| VIII. CI Gate | PASS | No CI-breaking changes expected (config template + unit file) |

**Gate result**: ALL PASS — no violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/005-activate-openclaw-bot/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0: provider API type, model IDs, migration strategy
├── data-model.md        # Phase 1: config schema changes
├── quickstart.md        # Phase 1: implementation guide
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
states/
├── configs/
│   └── openclaw.json.j2          # MODIFY: swap Anthropic → ProxyPilot provider
├── units/user/
│   └── openclaw-gateway.service  # MODIFY: add Wants/After proxypilot.service
└── openclaw_agent.sls            # MODIFY: add migration state, remove anthropic_key
```

**Structure Decision**: No new files created. All changes are edits to existing files within the established Salt state structure. This aligns with Constitution Principle V (Minimal Change).
