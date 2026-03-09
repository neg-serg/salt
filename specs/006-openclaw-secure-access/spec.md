# Feature Specification: OpenClaw Secure Access & Capability Expansion

**Feature Branch**: `006-openclaw-secure-access`
**Created**: 2026-03-09
**Status**: Draft
**Input**: User description: "Expand OpenClaw capabilities (file management, desktop control, email) with secure remote access — only the owner or explicitly authorized users can access it, while keeping the system convenient and not painful to use"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Remote Access to OpenClaw (Priority: P1)

As the workstation owner, I want to access OpenClaw's Web UI from any device (phone, laptop, tablet) outside my home network, so I can interact with the AI agent from anywhere without exposing the service to the public internet.

**Why this priority**: This is the foundation — all other capabilities (files, desktop, email) are only useful if they can be accessed remotely and securely. Currently the Web UI is localhost-only.

**Independent Test**: Connect to OpenClaw Web UI from a device on mobile data (different network), complete an AI conversation, and verify no information leaks to unauthorized parties.

**Acceptance Scenarios**:

1. **Given** the owner is on a remote network, **When** they connect using their authorized credentials, **Then** they reach the OpenClaw Web UI and can interact with the AI agent normally
2. **Given** an unauthorized person discovers the service endpoint, **When** they attempt to connect, **Then** they are denied access with no information leakage about what the service is
3. **Given** the owner has completed initial setup, **When** they reconnect the next day from a different device, **Then** they reach OpenClaw within 10 seconds without re-entering credentials
4. **Given** the workstation's IP changes (dynamic IP behind NAT), **When** the owner connects using the stable address, **Then** the connection works without manual reconfiguration

---

### User Story 2 - Desktop Environment Control via OpenClaw (Priority: P2)

As the workstation owner, I want to ask the AI agent to manage my Hyprland desktop — switch workspaces, move windows, take screenshots, launch applications — so I can control my workstation remotely through natural language commands.

**Why this priority**: The owner already has a Hyprland MCP server configured locally. Exposing desktop control through OpenClaw (especially remotely) is a natural high-value extension that leverages existing infrastructure.

**Independent Test**: Through the OpenClaw Web UI (locally or remotely), ask the agent to "switch to workspace 3" or "take a screenshot" and verify the action executes on the Hyprland desktop.

**Acceptance Scenarios**:

1. **Given** the owner is connected to OpenClaw, **When** they ask "switch to workspace 5", **Then** the Hyprland desktop switches to workspace 5
2. **Given** the owner is connected remotely, **When** they ask "take a screenshot of the current screen", **Then** they receive the screenshot in the chat
3. **Given** the owner asks to launch an application, **When** the agent executes the launch, **Then** the application appears on the desktop and the agent confirms success
4. **Given** an invited user is connected, **When** they attempt desktop control commands, **Then** the commands are denied (desktop control is owner-only)

---

### User Story 3 - File Management via OpenClaw (Priority: P2)

As the workstation owner, I want to ask the AI agent to browse, search, read, and manage files on my workstation, so I can access my documents, configs, and media from anywhere through natural language.

**Why this priority**: File management is a core "remote workstation" capability. Combined with secure remote access, it turns OpenClaw into a practical remote administration tool. Shares P2 with desktop control as both extend core agent capabilities.

**Independent Test**: Through OpenClaw, ask the agent to "list files in ~/doc" or "find the most recent PDF in ~/dw" and verify correct results.

**Acceptance Scenarios**:

1. **Given** the owner is connected, **When** they ask to list files in a directory, **Then** the agent returns an accurate file listing
2. **Given** the owner asks to read a specific file, **When** the file exists and is within allowed paths, **Then** the agent returns the file contents
3. **Given** the owner asks to move or copy a file, **When** the operation is within allowed paths, **Then** the file is moved/copied and the agent confirms
4. **Given** a user asks to access files outside the allowed scope (e.g., `/etc/shadow`), **When** the agent evaluates the request, **Then** it refuses with a clear explanation
5. **Given** an invited user is connected, **When** they request file operations, **Then** only files within explicitly shared directories are accessible

---

### User Story 4 - Email Management via OpenClaw (Priority: P3)

As the workstation owner, I want to ask the AI agent to check, summarize, search, and draft replies to my emails, so I can manage my inbox conversationally without opening a mail client.

**Why this priority**: Email management is a convenience layer on top of existing mail infrastructure. It requires the mail stack to be accessible to OpenClaw, which depends on the secure access and skill infrastructure from P1/P2.

**Independent Test**: Through OpenClaw, ask "do I have new emails?" and verify the agent reads from the mail system and returns an accurate summary.

**Acceptance Scenarios**:

1. **Given** the owner is connected, **When** they ask "check my email" or "any new mail?", **Then** the agent queries the mail system and returns a summary of unread messages
2. **Given** the owner asks to search emails, **When** they provide a search query (sender, subject, date range), **Then** the agent returns matching messages
3. **Given** the owner asks to draft a reply, **When** they provide the intent, **Then** the agent composes a draft and presents it for approval before sending
4. **Given** the owner approves a draft, **When** the agent sends it, **Then** the email is sent through the configured mail system and the agent confirms delivery
5. **Given** an invited user is connected, **When** they attempt email operations, **Then** they are denied (email is owner-only)

---

### User Story 5 - Invite Trusted Users (Priority: P3)

As the workstation owner, I want to grant specific people access to my OpenClaw instance with controlled permissions, so they can use the AI agent without me sharing my own credentials or exposing sensitive capabilities.

**Why this priority**: The owner explicitly requires controlled multi-user access. However, it depends on the secure access infrastructure (P1) being in place first, and the permission model for capabilities (P2) being defined.

**Independent Test**: Create an invitation for a trusted person, have them connect from their device, verify they can chat with the AI agent but cannot access desktop control, email, or files outside shared directories.

**Acceptance Scenarios**:

1. **Given** the owner wants to share access, **When** they generate an invite (command or link), **Then** the invited user can connect to OpenClaw within 5 minutes using only a browser
2. **Given** an invited user has access, **When** the owner revokes it, **Then** the user immediately loses access
3. **Given** multiple users are connected, **When** they interact with the AI, **Then** each user's conversations are isolated
4. **Given** an invited user is connected, **When** they attempt owner-only actions (desktop, email, full filesystem), **Then** those actions are denied

---

### User Story 6 - Operational Continuity and Self-Healing (Priority: P1)

As the workstation owner, I want the secure access system to maintain itself automatically — renewing certificates, recovering from failures, monitoring for anomalies — so I don't have to babysit it or discover that access broke days ago.

**Why this priority**: Shares P1 with remote access itself. A secure tunnel that silently dies after a week is worse than no tunnel at all — the owner loses trust and falls back to insecure workarounds. This isn't a one-time deployment; it's a continuously running property of the system.

**Independent Test**: Simulate a service crash (kill the tunnel process), wait 60 seconds, verify automatic recovery. Check that certificates renew before expiry. Verify the owner receives a notification when something requires attention.

**Acceptance Scenarios**:

1. **Given** the secure access tunnel crashes or loses connection, **When** 60 seconds pass, **Then** the system automatically restarts the tunnel and restores remote access without owner intervention
2. **Given** a TLS certificate is approaching expiry, **When** the renewal window opens, **Then** the certificate is renewed automatically and the service continues without interruption
3. **Given** the owner wants to check system health, **When** they query the status (via OpenClaw chat, Telegram, or CLI), **Then** they see: tunnel status (up/down + uptime), certificate expiry date, last successful remote connection, and any recent errors
4. **Given** a critical failure occurs that automatic recovery cannot fix, **When** the system detects it, **Then** the owner receives a notification (via Telegram bot or other configured channel) with the specific error
5. **Given** Salt is reapplied, **When** the secure access configuration is unchanged, **Then** the system continues running without interruption (idempotent apply)

---

### Edge Cases

- What happens when the workstation is powered off or OpenClaw is stopped? Remote users should see a clear "offline" indicator rather than a hanging connection.
- What happens during a Salt apply that restarts OpenClaw? Active sessions should reconnect automatically after the restart.
- What happens if a file operation targets a symlink that points outside allowed paths? The system must resolve symlinks before checking path permissions.
- What happens if the desktop session is locked (screen locker active)? Desktop control commands should either unlock (owner-only with confirmation) or report the locked state.
- What happens if the mail system is unreachable (e.g., network issue, service down)? The agent should report the specific error rather than failing silently.
- What happens if an invited user's credentials are compromised? The owner must be able to revoke access instantly, and the compromised credentials must not grant access to any other system resource.
- What happens if the automatic recovery enters a crash loop (e.g., misconfigured tunnel)? The system must back off exponentially and alert the owner rather than consuming resources in a tight restart loop.
- What happens if certificate renewal fails repeatedly? The system must alert the owner well before the certificate actually expires, giving time for manual intervention.

## Requirements *(mandatory)*

### Functional Requirements

**Secure Remote Access**:

- **FR-001**: System MUST provide encrypted remote access to the OpenClaw Web UI without exposing the service directly on a public IP/port
- **FR-002**: System MUST authenticate users before granting access — only the owner and explicitly invited users may connect
- **FR-003**: System MUST persist user sessions so returning users are not forced to re-authenticate on every visit
- **FR-004**: System MUST handle dynamic IP / NAT changes without requiring manual reconfiguration by the owner
- **FR-005**: System MUST continue to work locally (127.0.0.1) without the remote access layer, as a fallback

**User Management**:

- **FR-006**: System MUST allow the owner to invite new users with a simple action (single command or link generation)
- **FR-007**: System MUST allow the owner to revoke any user's access at any time, with immediate effect
- **FR-008**: System MUST isolate conversations between users — no user can see another's AI interactions

**Capability Extension — Desktop Control**:

- **FR-009**: System MUST expose Hyprland desktop control (workspace switching, window management, screenshots, app launching) to the AI agent via a skill
- **FR-010**: Desktop control capabilities MUST be restricted to the owner only — invited users cannot execute desktop commands
- **FR-011**: Desktop control MUST work through natural language commands in the OpenClaw chat interface

**Capability Extension — File Management**:

- **FR-012**: System MUST expose file browsing, searching, reading, and basic file operations (copy, move, rename) to the AI agent via a skill
- **FR-013**: File access MUST be scoped to configurable allowed paths (e.g., `~/doc`, `~/dw`, `~/music`, `~/pic`, `~/vid`) — not unrestricted filesystem access
- **FR-014**: Invited users MUST only access files within explicitly shared directories (a subset of the owner's allowed paths)
- **FR-015**: File operations MUST resolve symlinks and reject operations that would escape allowed path boundaries

**Capability Extension — Email**:

- **FR-016**: System MUST expose email operations (check inbox, search, read, draft replies, send) to the AI agent via a skill that uses notmuch for indexing/search/read and msmtp for sending — the existing local mail pipeline (mbsync syncs Gmail → maildir at `~/.local/mail/`, notmuch indexes it, msmtp sends via Gmail SMTP)
- **FR-017**: Email capabilities MUST be restricted to the owner only
- **FR-018**: The agent MUST present draft replies for owner approval before sending — no auto-send without confirmation

**Operational Continuity**:

- **FR-022**: System MUST automatically restart the secure access tunnel on failure, with exponential backoff to prevent crash loops
- **FR-023**: System MUST automatically renew TLS certificates before expiry without service interruption
- **FR-024**: System MUST provide a health status check accessible via CLI, OpenClaw chat, or Telegram — showing tunnel status, certificate expiry, uptime, and recent errors
- **FR-025**: System MUST notify the owner (via Telegram or other configured channel) when automatic recovery fails or when manual intervention is required
- **FR-026**: System MUST survive Salt reapplies idempotently — unchanged configuration must not cause service restarts or access interruptions

**Infrastructure**:

- **FR-019**: All new components MUST be deployable and maintainable via Salt states, consistent with the existing infrastructure-as-code approach
- **FR-020**: System MUST NOT require invited users to install specialized software beyond a standard web browser
- **FR-021**: OpenClaw skills MUST be deployed as SKILL.md files managed by Salt, not manually configured

### Key Entities

- **Owner**: The workstation administrator (user `neg`) with full access to all capabilities — desktop, files, email, user management
- **Invited User**: A person explicitly granted access by the owner, with permissions limited to AI chat and optionally shared file directories
- **Skill**: An OpenClaw extension (SKILL.md file) that teaches the agent how to perform a specific category of actions (desktop control, file management, email)
- **Session**: An authenticated connection with persistence, tied to a specific user identity
- **Allowed Paths**: A configurable set of filesystem directories that the file management skill can access, different for owner vs. invited users

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Owner can access OpenClaw Web UI from any remote network within 10 seconds of opening the connection (after initial one-time setup)
- **SC-002**: Initial setup for secure remote access takes under 15 minutes, including Salt apply and first remote connection
- **SC-003**: Inviting a new user takes under 2 minutes; the invited user completes first connection in under 5 minutes with only a browser
- **SC-004**: Unauthorized connection attempts are blocked with zero information leakage about the service
- **SC-005**: Desktop control commands (switch workspace, take screenshot, launch app) execute within 3 seconds of the request
- **SC-006**: File operations (list, read, search) return results within 5 seconds for typical directory sizes
- **SC-007**: Email check returns inbox summary within 10 seconds
- **SC-008**: Owner can revoke any user's access within 30 seconds, with immediate effect
- **SC-009**: 100% of AI conversations remain isolated — no user can access another user's history
- **SC-010**: The system survives workstation IP changes, service restarts, and Salt reapplies without manual intervention
- **SC-011**: All three new capabilities (desktop, files, email) function correctly through both local and remote access
- **SC-012**: The secure access tunnel recovers automatically from crashes within 60 seconds, without owner intervention
- **SC-013**: TLS certificates are renewed automatically at least 7 days before expiry
- **SC-014**: Owner can check full system health status in under 5 seconds via any access channel (CLI, chat, Telegram)

## Assumptions

- The workstation runs continuously (or has predictable uptime) — remote access only works when the machine is on and OpenClaw is running
- The owner has a domain name available via DuckDNS (already configured in `services.sls`) for stable addressing despite dynamic IPs
- Telegram bot access (already configured with allowlist policy) continues to work independently of Web UI remote access and is not affected by this feature
- ProxyPilot remains the sole AI provider backend — this feature does not change the AI routing architecture
- OpenClaw's current skill system (SKILL.md files) is the extension mechanism — native MCP support is not yet available in OpenClaw and is not relied upon
- The owner's threat model is "prevent unauthorized access from the internet" — standard encryption and authentication are sufficient (not defending against state-level adversaries)
- Desktop control via Hyprland is inherently owner-only because it operates on the physical display session — this is a security boundary, not just a policy choice
- File management uses the project's standard XDG short paths (`~/doc`, `~/dw`, `~/music`, `~/pic`, `~/vid`) as defined in `environment.d/10-user.conf`
- User conversation isolation relies on OpenClaw's existing per-session separation (session.dmScope: per-channel-peer)
- The mail pipeline is Gmail-based: mbsync syncs IMAP to local maildir at `~/.local/mail/gmail/`, notmuch indexes for search, msmtp sends via Gmail SMTP — all already deployed via Salt user services
- Notifications about system health failures can be routed through the existing OpenClaw Telegram bot (already configured with allowlist policy)
