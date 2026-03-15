# Implementation Plan: pyinfra Migration Research

**Branch**: `030-pyinfra-migration-research` | **Date**: 2026-03-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/030-pyinfra-migration-research/spec.md`

## Summary

Research deliverable evaluating whether migrating from Salt (masterless) to pyinfra would improve deployment speed for a single CachyOS workstation. Research concludes **NO-GO**: pyinfra's speed advantage is about SSH fan-out to many hosts and is irrelevant for single-host local execution. Migration would regress parallel downloads (+30 min on fresh apply), require 3-5 weeks of rewriting 35 macros and 41 state files, and trade a mature ecosystem for a single-maintainer project.

## Technical Context

**Language/Version**: N/A — research deliverable, no code produced
**Primary Dependencies**: Salt 3006.x (current), pyinfra v3.7 (comparison target)
**Storage**: N/A
**Testing**: Manual benchmarking (wall-clock timing), feature parity matrix review
**Target Platform**: CachyOS (Arch-based) single workstation, masterless mode
**Project Type**: Research/analysis document
**Performance Goals**: Quantify Salt vs pyinfra deployment speed difference with <10% measurement error
**Constraints**: Single-host only (no SSH fan-out), must evaluate `@local` connector specifically
**Scale/Scope**: 36 SLS state files, 5 macro files (35 macros, 173 invocations), ~15 YAML data files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Idempotency | N/A | Research deliverable — no Salt states produced |
| II. Network Resilience | N/A | No network-accessing states |
| III. Secrets Isolation | Pass | No secrets involved |
| IV. Macro-First | N/A | No Salt states produced |
| V. Minimal Change | Pass | Research-only, no code changes to existing states |
| VI. Convention Adherence | Pass | Documentation follows `[scope] description` commit style, English primary |
| VII. Verification Gate | N/A | No state changes to verify |
| VIII. CI Gate | Pass | Documentation-only branch |

**Pre-research gate: PASS** — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/030-pyinfra-migration-research/
├── plan.md              # This file
├── research.md          # Phase 0 output — complete benchmark analysis and recommendation
├── spec.md              # Feature specification
└── checklists/
    └── requirements.md  # Specification quality checklist
```

### Source Code (repository root)

No source code produced. This is a research-only deliverable.

## Phase 0: Research — Complete

All research consolidated in [research.md](research.md). Key findings:

1. **Benchmark data**: pyinfra's official benchmarks (Fizzadar/pyinfra-performance) measure SSH fan-out — 5-8x faster than Ansible at 100+ hosts. Salt not benchmarked. No `@local` vs `salt-call --local` comparison exists anywhere.

2. **Architecture analysis**: Both tools use Python subprocess for local execution. State compilation overhead (Jinja2+YAML vs Python import) is ~2-5s vs ~0.5-1s — negligible on 5-30 min total apply.

3. **Feature gap matrix**: 14 Salt features mapped. Critical gaps: no single-host `parallel: True` (regression), verbose `watch`/`onchanges` replacement (15 directives to rewrite), two-phase fact staleness problem.

4. **Codebase audit**: 35 macros with 173 invocations across 41 files. 4 states use `parallel: True` (ollama models, video_ai models — high-impact concurrent downloads). 15 watch/onchanges directives (mostly macro-driven).

5. **Project health**: pyinfra has bus factor = 1 (~4.9k stars, ~30 contributors). Salt has 500+ contributors (~15.3k stars) but Broadcom neglect post-acquisition.

**Decision**: NO-GO. See research.md for full analysis.

## Phase 1: Design — N/A

This is a research deliverable. No data model, contracts, or quickstart needed:

- **data-model.md**: Not applicable (no persistent data)
- **contracts/**: Not applicable (no external interfaces)
- **quickstart.md**: Not applicable (no code to run)

## Post-Design Constitution Re-check

| Principle | Status |
|-----------|--------|
| All principles | N/A or Pass — research deliverable, no state changes |

**Post-design gate: PASS**

## Recommended Next Steps (outside this feature)

Instead of migrating to pyinfra, optimize existing Salt:

1. **Add more `parallel: True`** — audit states for independent download/install operations that could run concurrently
2. **Profile bottlenecks** — use `just profile-trend` to identify actual slow states
3. **Pre-built package caches** — for frequently-rebuilt PKGBUILDs (amnezia, custom_pkgs)
4. **Review idempotency guards** — ensure `unless:`/`creates:` guards prevent unnecessary re-evaluations
