# Implementation Plan: ProxyPilot Free Model Fallback

**Branch**: `003-proxypilot-free-fallback` | **Date**: 2026-03-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-proxypilot-free-fallback/spec.md`

## Summary

Add 5 free cloud AI providers (Groq, Mistral, Cerebras, OpenRouter, SambaNova) plus local Ollama as cascading emergency fallback tiers in ProxyPilot. Uses ProxyPilot's native `openai-compatibility` config section for custom backends with direct API keys. All configuration is data-driven via `states/data/free_providers.yaml`, secrets live in gopass, and the existing Grafana dashboard gets new panels for fallback observability. Activation is emergency-only — free providers never route when paid providers are healthy.

## Technical Context

**Language/Version**: YAML/Jinja2 (Salt states), YAML (chezmoi templates), JSON (Grafana dashboard)
**Primary Dependencies**: Salt 3006+, ProxyPilot v0.3.0-dev-0.40 (CLIProxyAPI engine), chezmoi, gopass, Ollama
**Storage**: N/A (configuration management only — no application data)
**Testing**: `just` (Salt render verification), manual `curl` against ProxyPilot endpoints, Grafana dashboard visual verification
**Target Platform**: CachyOS (Arch-based) workstation, systemd user services
**Project Type**: Configuration management (Salt states + chezmoi dotfiles)
**Performance Goals**: Fallback response within 30 seconds when primary provider fails
**Constraints**: Zero monetary cost, no credit card required for any provider, secrets via gopass only
**Scale/Scope**: Single workstation, 6 fallback providers (5 cloud + 1 local), ~5 files modified/created

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | PASS | No new `cmd.run` states — only `file.managed` (Salt template) and `import_yaml` (data file). Existing macros enforce guards. |
| II. Network Resilience | PASS | ProxyPilot handles retry/failover internally (`request-retry: 3`, `max-retry-credentials: 3`). No new network-accessing Salt states needed — config is deployed locally. |
| III. Secrets Isolation | PASS | All free provider API keys stored in gopass (`api/groq`, `api/mistral`, etc.). Injected via Salt Jinja context from `gopass_secret()` macro. No plaintext secrets in repo. |
| IV. Macro-First | PASS | No new infrastructure patterns needed. Existing `file.managed` and `gopass_secret()` patterns used. |
| V. Minimal Change | PASS | Changes scoped to: 1 data file, 1 Salt template, 1 Salt state, 1 Grafana dashboard. No unnecessary abstractions. |
| VI. Convention Adherence | PASS | State IDs follow `target_descriptor` pattern. Data file follows `installers.yaml` schema pattern. Commits scoped `[proxypilot]`. |
| VII. Verification Gate | PASS | `just` will be run after changes to verify Salt renders. |
| VIII. CI Gate | PASS | Branch-based, CI must pass before merge. |

No violations. No complexity tracking entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/003-proxypilot-free-fallback/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Phase 0: provider research, config format discovery
├── data-model.md        # Phase 1: entity/data definitions
├── quickstart.md        # Phase 1: deployment guide
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
states/
├── data/
│   └── free_providers.yaml        # NEW: free provider definitions (data-driven)
├── configs/
│   ├── proxypilot.yaml.j2         # MODIFIED: add openai-compatibility section
│   └── grafana-dashboard-proxypilot.json  # MODIFIED: add fallback panels
└── opencode.sls                   # MODIFIED: inject free provider API keys into template context
```

**Structure Decision**: This is a configuration-management-only feature. No new source code directories needed. All changes are to existing Salt state files, config templates, and data files, plus one new YAML data file (`free_providers.yaml`). No contracts directory needed — ProxyPilot is an internal proxy with no externally-facing API changes.
