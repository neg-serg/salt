# Feature Specification: Activate OpenClaw Telegram Bot

**Feature Branch**: `005-activate-openclaw-bot`
**Created**: 2026-03-08
**Status**: Draft
**Input**: User description: "Мне надо чтобы бот заработал которого мы настраивали. Сейчас есть например вроде как работающие модели через proxypilot, так что он по идее может начать отвечать. От него надо добиться работы."

## Clarifications

### Session 2026-03-08

- Q: Should the config keep direct Anthropic API alongside ProxyPilot, or switch to ProxyPilot-only? → A: ProxyPilot-only — remove direct Anthropic provider entirely, simplify config.
- Q: Should this feature force-redeploy the config or only update the template? → A: Force-redeploy — delete existing config and reseed from updated template.
- Q: Which model should be the default for the bot? → A: Claude Sonnet 4.6 via ProxyPilot OAuth. Stable operation through OAuth routing must be verified and ensured.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send a message to Telegram bot and get an AI response (Priority: P1)

The user sends a direct message to the OpenClaw Telegram bot. The bot processes the message through an AI model routed via ProxyPilot and responds with an AI-generated reply in the same Telegram chat.

**Why this priority**: This is the core value proposition — the bot must respond to messages. Without this, nothing else matters.

**Independent Test**: Send any text message (e.g., "Привет, как дела?") to the bot in Telegram. The bot should reply within a reasonable time with a coherent AI-generated response.

**Acceptance Scenarios**:

1. **Given** the OpenClaw gateway service is running and the Telegram channel is connected, **When** the allowlisted user sends a text message to the bot, **Then** the bot responds with an AI-generated reply within 60 seconds.
2. **Given** the OpenClaw gateway is running, **When** a non-allowlisted user sends a message, **Then** the bot ignores the message (allowlist policy enforced).
3. **Given** the OpenClaw gateway is running, **When** someone sends a message in a group where the bot is a member, **Then** the bot does not respond (group policy disabled).

---

### User Story 2 - Bot routes requests through ProxyPilot to available models (Priority: P1)

The OpenClaw bot uses ProxyPilot as its AI model provider, leveraging whatever models ProxyPilot currently has available (Claude via OAuth, DeepSeek, Groq, Cerebras, etc.). This replaces direct Anthropic API calls (which require a paid API key) with ProxyPilot routing that can use free/OAuth-based providers.

**Why this priority**: The user explicitly states ProxyPilot has working models. Routing through ProxyPilot is what makes the bot viable without a dedicated Anthropic API key.

**Independent Test**: Check that the OpenClaw config has ProxyPilot as a provider, and that `openclaw models list` shows models available through ProxyPilot. Send a test message and verify the response comes via ProxyPilot (check ProxyPilot logs for the routed request).

**Acceptance Scenarios**:

1. **Given** ProxyPilot is running with Claude Sonnet 4.6 available via OAuth, **When** OpenClaw receives a user message, **Then** it routes the AI request through ProxyPilot and returns the model's response.
2. **Given** ProxyPilot has multiple models available, **When** the primary model is rate-limited or unavailable, **Then** OpenClaw falls back to the next available model via ProxyPilot's routing.
3. **Given** the bot has been running for an extended period, **When** multiple messages are sent over time, **Then** ProxyPilot's OAuth routing remains stable (no token expiration failures, no silent drops).

---

### User Story 3 - Service starts reliably and recovers from failures (Priority: P2)

The OpenClaw gateway service starts automatically on boot (via systemd user service with lingering), declares its dependency on ProxyPilot, and recovers from transient failures (network issues, provider timeouts).

**Why this priority**: Reliability ensures the bot stays available without manual intervention, but it's secondary to basic functionality.

**Independent Test**: Restart the `openclaw-gateway` service and verify it comes up cleanly. Stop ProxyPilot, verify OpenClaw handles the outage gracefully, then restart ProxyPilot and verify OpenClaw recovers.

**Acceptance Scenarios**:

1. **Given** the system has just booted, **When** the user's systemd session starts, **Then** `openclaw-gateway.service` starts automatically after `proxypilot.service`.
2. **Given** the gateway is running, **When** ProxyPilot temporarily becomes unavailable, **Then** the gateway logs an error but does not crash, and resumes routing when ProxyPilot recovers.
3. **Given** the gateway crashes, **When** systemd detects the failure, **Then** it restarts the gateway automatically within 10 seconds.

---

### Edge Cases

- What happens when all ProxyPilot models are rate-limited simultaneously? The bot should inform the user that no models are currently available rather than hanging silently.
- What happens when the Telegram bot token is invalid or expired? The gateway should log a clear error and the service should enter a failed state (not restart-loop).
- What happens when gopass is unavailable during Salt apply (e.g., no Yubikey inserted)? Salt should fail gracefully with a clear message, not deploy a config with empty secrets.
- What happens when OpenClaw rewrites its config at startup and changes the provider settings? After the initial force-redeploy, `replace: False` must be restored to prevent overwriting runtime modifications on subsequent applies.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The OpenClaw config template MUST use ProxyPilot as the sole model provider, pointing to the local ProxyPilot endpoint with the local API key. Direct Anthropic API provider MUST be removed.
- **FR-002**: The provider configuration MUST use OpenAI-compatible API type since ProxyPilot exposes an OpenAI-compatible endpoint.
- **FR-003**: The model list in the ProxyPilot provider MUST include at least one model identifier that ProxyPilot can route.
- **FR-004**: The default agent model MUST be set to Claude Sonnet 4.6 (`claude-sonnet-4-6-20250514`), routed through ProxyPilot's OAuth mechanism. Stable operation of this routing path MUST be verified.
- **FR-005**: The Telegram channel configuration MUST be present with a valid bot token, allowlist policy, and the user's Telegram ID.
- **FR-006**: The systemd unit for the OpenClaw gateway MUST declare a dependency on ProxyPilot to ensure correct startup ordering.
- **FR-007**: Salt MUST verify that all required secrets (Telegram token, Telegram user ID, ProxyPilot API key) are accessible before deploying the config. Direct Anthropic API key (`api/anthropic`) is NOT required.
- **FR-008**: The config deployment MUST force-redeploy the config file (delete existing + reseed from template) to ensure the updated provider settings take effect. After initial activation, subsequent applies SHOULD use a seed-only strategy (`replace: False`) to preserve runtime modifications.
- **FR-009**: The gateway MUST be accessible locally for Web UI access with token-based authentication.

### Key Entities

- **ProxyPilot Provider**: The AI model routing proxy, providing access to multiple upstream model providers (Claude OAuth, DeepSeek, Groq, Cerebras, etc.) through a single OpenAI-compatible endpoint.
- **OpenClaw Gateway**: The AI agent gateway that receives Telegram messages and routes them to model providers, managing sessions and conversation context.
- **Telegram Channel**: The messaging interface connecting the bot to users, configured with allowlist-based access control.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The bot responds to a direct message from the allowlisted user within 60 seconds of receiving it.
- **SC-002**: The bot successfully routes requests through ProxyPilot, confirmed by matching request traces in both service logs.
- **SC-003**: The gateway service remains running for at least 1 hour without crashes after initial activation.
- **SC-004**: Salt apply completes without errors related to OpenClaw states.
- **SC-005**: After a system reboot, the bot automatically resumes responding to messages without manual intervention.
- **SC-006**: ProxyPilot OAuth routing to Claude Sonnet 4.6 handles at least 10 consecutive requests without authentication failures or silent drops.

## Assumptions

- ProxyPilot is already installed, configured, and running with at least one routable model.
- The gopass secrets for the Telegram bot token and user ID are already provisioned.
- The Telegram bot was already created via BotFather and the token is stored in gopass.
- The user's Telegram numeric ID is already stored in gopass.
- Direct Anthropic API access is not used; ProxyPilot is the sole model route. The `api/anthropic` gopass secret is not required for this feature.
- OpenClaw npm package version 2026.3.2 is functional and supports the required provider configuration.
