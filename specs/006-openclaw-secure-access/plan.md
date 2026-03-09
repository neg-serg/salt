# Implementation Plan: OpenClaw Secure Access & Capability Expansion

**Branch**: `006-openclaw-secure-access` | **Date**: 2026-03-09 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-openclaw-secure-access/spec.md`

## Summary

Expand OpenClaw from a localhost-only AI agent to a securely accessible remote workstation assistant with desktop control, file management, and email capabilities. The system uses a Rathole tunnel through a VPS with Caddy providing TLS and authentication, three OpenClaw skills (Hyprland, files, email) wrapping existing CLI tools, a dual-agent architecture for owner vs. guest permissions, and systemd-based health monitoring with Telegram notifications.

## Technical Context

**Language/Version**: Jinja2/YAML (Salt states), Markdown (OpenClaw SKILL.md), TOML (Rathole config), Caddyfile, Zsh (scripts)
**Primary Dependencies**: Salt, OpenClaw 2026.3.2, Rathole (AUR), notmuch, msmtp, hyprctl, systemd
**Storage**: Files (Salt states, skill files, systemd units, config files)
**Testing**: `just` (Salt render verification), manual functional testing (tunnel connectivity, skill operations)
**Target Platform**: CachyOS (Arch-based) Linux workstation + minimal VPS (Caddy + Rathole server)
**Project Type**: Infrastructure-as-code (Salt states + chezmoi dotfiles)
**Performance Goals**: <3s desktop commands, <5s file operations, <10s email check, <10s remote connection
**Constraints**: No public ports on workstation, browser-only for invited users, all secrets via gopass, DuckDNS for dynamic IP
**Scale/Scope**: 1 workstation, 1 VPS, 1-5 concurrent users max

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Idempotency | PASS | All new `cmd.run` states use `creates:` or `unless:` guards. Skills via `file.managed` (inherently idempotent). Rathole install via `paru_install` macro. |
| II. Network Resilience | PASS | Rathole binary install uses `retry` + `parallel`. DuckDNS update already has retry in existing timer. |
| III. Secrets Isolation | PASS | Tunnel token → `gopass api/openclaw-tunnel-token`. Caddy auth passwords → `gopass api/openclaw-tunnel-owner` and `api/openclaw-tunnel-guest-*`. No plaintext secrets. |
| IV. Macro-First | PASS | Use `paru_install` for Rathole package. Use `user_service_file` and `user_service_enable` for systemd units. Use `ensure_dir` for directories. |
| V. Minimal Change | PASS | Only creates necessary files: 1 new Salt state, 3 skills, 2 systemd units, 1 health script. Modifies existing `openclaw_agent.sls` and `openclaw.json.j2` minimally. |
| VI. Convention Adherence | PASS | State IDs: `target_descriptor` (e.g., `rathole_config`, `openclaw_hyprland_skill`). Scripts: `#!/usr/bin/env zsh`. XDG paths: `~/doc`, `~/dw`, etc. Commit: `[openclaw]`. |
| VII. Verification Gate | PASS | `just` run required before completion. |
| VIII. CI Gate | PASS | CI must pass. |

**Post-Phase 1 re-check**: All principles still satisfied. No violations introduced by design decisions.

## Project Structure

### Documentation (this feature)

```text
specs/006-openclaw-secure-access/
├── plan.md              # This file
├── research.md          # Phase 0: tunnel, skills, auth, health research
├── data-model.md        # Phase 1: configuration entities
├── quickstart.md        # Phase 1: getting started guide
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
states/
├── openclaw_agent.sls              # MODIFIED: add skill deployment, dual-agent config
├── openclaw_tunnel.sls             # NEW: Rathole client service + health monitoring
├── configs/
│   ├── openclaw.json.j2            # MODIFIED: dual-agent config (owner + guest)
│   └── rathole-client.toml.j2      # NEW: Rathole tunnel client config
├── units/
│   └── user/
│       ├── openclaw-tunnel.service  # NEW: Rathole client systemd user service
│       ├── openclaw-health.service  # NEW: health check oneshot service
│       └── openclaw-health.timer    # NEW: health check timer (every 5 min)
├── scripts/
│   ├── openclaw-health-check.sh     # NEW: health check + Telegram notification
│   └── openclaw-invite.sh           # NEW: guest credential generation helper
├── data/
│   ├── versions.yaml               # MODIFIED: add rathole version pin
│   └── openclaw_skills.yaml         # NEW: skill definitions (data-driven)
│
dotfiles/
└── dot_openclaw/
    └── skills/
        ├── hyprland-desktop/
        │   └── SKILL.md             # NEW: Hyprland desktop control skill
        ├── file-manager/
        │   └── SKILL.md             # NEW: file management skill
        └── email-notmuch/
            └── SKILL.md             # NEW: email management skill
```

**Structure Decision**: Infrastructure-as-code project — no `src/` or `tests/` directories. Salt states manage system configuration. Skills are deployed as chezmoi dotfiles to `~/.openclaw/skills/`. New Salt state `openclaw_tunnel.sls` handles tunnel infrastructure; existing `openclaw_agent.sls` is extended for skills and multi-agent config.

Skills go through chezmoi (not Salt `file.managed`) because they live under `~/.openclaw/` which is a user-owned directory already partially managed by OpenClaw itself. Chezmoi handles the initial deployment, and since skills don't self-modify (unlike `openclaw.json`), there's no conflict.

## Complexity Tracking

No constitution violations. No complexity justifications needed.
