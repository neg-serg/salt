# Tasks: OpenClaw Capability Expansion

**Input**: Design documents from `/specs/006-openclaw-secure-access/`

**Architecture**: OpenClaw stays localhost-only (127.0.0.1:18789). Remote access via Telegram bot (already configured). Future: Tailscale for Web UI access (see TODO.md).

**Scope**: Skills (Hyprland, files, email), health monitoring, dual-agent config preparation.

---

## Phase 1: Setup

**Purpose**: Directory structure and shared data files

- [x] T001 [P] Create chezmoi directory structure: `dotfiles/dot_openclaw/skills/hyprland-desktop/`, `dotfiles/dot_openclaw/skills/file-manager/`, `dotfiles/dot_openclaw/skills/email-notmuch/`
- [x] T002 [P] Add OpenClaw skill definitions to `states/data/openclaw_skills.yaml` (data-driven list of skill names, paths, required binaries)

---

## Phase 2: Foundational (Dual-Agent Config)

**Purpose**: Prepare dual-agent config for future guest access (Tailscale)

- [x] T003 Modify `states/configs/openclaw.json.j2` to add dual-agent config: owner agent (`id: "main"`, `tools.profile: "full"`) and guest agent (`id: "guest"`, `tools.profile: "minimal"`, `tools.deny: ["exec","browser","gateway","cron"]`)
- [x] T004 Add config migration state `openclaw_dualagent_migrate` to `states/openclaw_agent.sls`: delete existing `openclaw.json` when it lacks `agents.list` key, enabling `replace: False` reseed with dual-agent config

---

## Phase 3: Health Monitoring (Operational Continuity)

**Goal**: OpenClaw gateway self-heals on failure, owner gets Telegram alerts on persistent failure.

- [x] T005 Create health check script at `states/scripts/openclaw-health-check.sh` (zsh): check gateway service active, curl localhost:18789. Alert via direct Telegram Bot API. 30-minute cooldown via state file at `~/.cache/openclaw-health-state`
- [x] T006 [P] Create `openclaw-health.service` oneshot unit at `states/units/user/openclaw-health.service`
- [x] T007 [P] Create `openclaw-health.timer` unit at `states/units/user/openclaw-health.timer` with `OnBootSec=5min`, `OnUnitActiveSec=5min`, `Persistent=true`
- [x] T008 Add health monitoring deployment to `states/openclaw_agent.sls`: deploy health script, service, and timer units. Enable timer

---

## Phase 4: Skills

**Goal**: Expand OpenClaw capabilities with desktop control, file management, and email.

- [x] T009 [P] Create Hyprland desktop skill at `dotfiles/dot_openclaw/skills/hyprland-desktop/SKILL.md`: workspace switching, window management, app launching, screenshots via grim. Safety: confirm before closing windows
- [x] T010 [P] Create file manager skill at `dotfiles/dot_openclaw/skills/file-manager/SKILL.md`: allowed paths (`~/doc`, `~/dw`, `~/music`, `~/pic`, `~/vid`, `~/src`, `/tmp`), `realpath` validation, no deletion support
- [x] T011 [P] Create email skill at `dotfiles/dot_openclaw/skills/email-notmuch/SKILL.md`: notmuch search/read, msmtp send with mandatory draft-before-send, mbsync sync

---

## Phase 5: Verification

- [x] T012 Run `just` to verify Salt renders cleanly with all changes to `openclaw_agent.sls`
- [x] T013 Functional test (manual): verify health timer starts, test each skill via local Web UI and Telegram bot
- [x] T014 Write future expansion note at `specs/006-openclaw-secure-access/TODO.md` describing Tailscale integration path

---

## Notes

- Remote access is Telegram-only for now; Tailscale described in TODO.md as future expansion
- Skills use chezmoi deployment (`dotfiles/dot_openclaw/skills/`) not Salt `file.managed`
- Health check alerts use direct Telegram Bot API (not through OpenClaw) to avoid circular dependency
- Dual-agent config is preparation for Tailscale guest access — currently unused
- No tunnel infrastructure (Rathole, Caddy, VPS) — removed per user decision
- Total: 14 tasks across 5 phases
