# Feature Specification: ProxyPilot Free Model Fallback

**Feature Branch**: `003-proxypilot-free-fallback`
**Created**: 2026-03-08
**Status**: Draft
**Input**: User description: "Расширить ProxyPilot бесплатными моделями так чтобы всегда была модель на fallback, включая внешнее облако, но бесплатно"

## Clarifications

### Session 2026-03-08

- Q: Should free providers only activate when paid providers fail (emergency-only), be used alongside paid for load distribution, or hybrid? → A: Emergency-only — free providers activate only when all paid providers fail.
- Q: Should local Ollama be included as the final fallback tier (after all cloud free providers), cloud-only, or Ollama-first? → A: Include Ollama as final fallback tier — after all cloud free providers exhaust, local Ollama serves as the last-resort zero-dependency safety net.
- Q: Should free provider usage be observable? Log-only, extend existing Grafana dashboard, or add alerting? → A: Extend existing Grafana dashboard with free provider panels (fallback activation count, per-provider error rates, Ollama usage).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Always-Available AI Fallback (Priority: P1)

When all paid/primary providers (Anthropic direct, Antigravity/Gemini OAuth) are unavailable due to rate limits, TOS blocks, account issues, or network errors, AI coding tools (Claude Code, OpenCode, OpenClaw) seamlessly fall back to free cloud-hosted models through ProxyPilot — without any user intervention.

**Why this priority**: This is the core value proposition. The user currently has Antigravity routes returning 403 (Google TOS-blocked) and depends on Anthropic direct access. If Anthropic has an outage or rate-limits, there is zero fallback — all AI tooling stops working. This story ensures continuous availability.

**Independent Test**: Can be fully tested by stopping/blocking the primary Anthropic provider and verifying that AI tool requests still receive responses from a free fallback provider within acceptable time.

**Acceptance Scenarios**:

1. **Given** the primary Anthropic provider is unreachable, **When** an AI tool sends a request through ProxyPilot, **Then** ProxyPilot routes the request to a free fallback provider and returns a valid response
2. **Given** a free fallback provider hits its rate limit, **When** another request arrives, **Then** ProxyPilot automatically tries the next free provider in the fallback chain
3. **Given** all cloud free providers are temporarily exhausted, **When** a request arrives, **Then** ProxyPilot routes the request to the local Ollama instance as the last-resort fallback
4. **Given** all providers including local Ollama are unavailable, **When** a request arrives, **Then** ProxyPilot returns a clear error indicating all providers are unavailable with retry guidance

---

### User Story 2 - Multiple Free Provider Registration (Priority: P1)

The system registers multiple free cloud AI providers (at minimum 3) in ProxyPilot's configuration, each with their own API keys, base URLs, and model mappings. Providers are configured via Salt states and Salt Jinja templates following existing patterns.

**Why this priority**: Having a single free fallback is not reliable — free tiers have rate limits that can be exhausted quickly. Multiple providers create a cascading fallback chain that dramatically increases availability. Co-equal with Story 1 since the fallback mechanism requires multiple providers to be useful.

**Independent Test**: Can be fully tested by verifying each configured free provider responds to a basic chat completion request independently.

**Acceptance Scenarios**:

1. **Given** a fresh Salt apply, **When** ProxyPilot starts, **Then** all configured free providers are listed in ProxyPilot's active routes
2. **Given** a free provider API key is stored in gopass, **When** Salt applies the config template, **Then** the key is injected into ProxyPilot's config without plaintext secrets in the repo
3. **Given** a new free provider needs to be added, **When** the operator adds its details to the data file and gopass, **Then** Salt apply deploys it without modifying existing provider configurations

---

### User Story 3 - Automatic Provider Health Monitoring (Priority: P2)

ProxyPilot continuously monitors the health/availability of all configured providers (both paid and free) and automatically adjusts routing priority based on current availability, response times, and rate limit status.

**Why this priority**: Without health monitoring, ProxyPilot may repeatedly try failed providers, adding latency to every request. Health-aware routing makes the fallback near-instant rather than waiting for timeouts on dead providers.

**Independent Test**: Can be tested by configuring one provider with an invalid API key and verifying that ProxyPilot stops routing to it after initial failures, then resumes when the key is fixed.

**Acceptance Scenarios**:

1. **Given** a provider returns consecutive errors, **When** a new request arrives, **Then** ProxyPilot deprioritizes that provider and tries healthy ones first
2. **Given** a previously-failed provider recovers, **When** the health check interval passes, **Then** ProxyPilot re-includes it in the routing pool

---

### User Story 4 - Model Quality Tiering (Priority: P3)

Free fallback models are organized into quality tiers so that the most capable free models are tried first before falling to smaller/faster ones. The user can influence tier ordering via configuration.

**Why this priority**: Not all free models are equal — a 70B parameter model produces much better code assistance than an 8B one. Tiering ensures the user gets the best available quality before degrading.

**Independent Test**: Can be tested by verifying the order of provider attempts matches the configured quality tiers when the top-tier provider is unavailable.

**Acceptance Scenarios**:

1. **Given** the primary paid provider fails, **When** ProxyPilot falls back, **Then** it tries the highest-quality free model first (e.g., large parameter models) before smaller models
2. **Given** the user has customized tier ordering in config, **When** fallback triggers, **Then** the custom ordering is respected

---

### Edge Cases

- What happens when all cloud providers (paid and free) are simultaneously unavailable? Local Ollama serves as the last-resort fallback with reduced model quality but guaranteed availability.
- What happens when even Ollama is unavailable (e.g., GPU failure, service crashed)? System returns a clear error with list of attempted providers and estimated recovery time.
- How does the system handle free providers that change their rate limits without notice? ProxyPilot dynamically adapts based on actual HTTP 429 responses rather than relying on pre-configured limits alone.
- What happens when a free provider deprecates a model? ProxyPilot logs warnings about failed model routes; the operator updates the model mapping in the data file and re-applies Salt.
- What happens when free providers require updated API keys? gopass secrets are updated by the operator; `just` (Salt apply) regenerates ProxyPilot config with new keys.
- How does the system handle free providers that train on input data? This is documented as a known trade-off. The fallback is only used when paid providers are unavailable — it is an emergency path, not a default route.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST configure at least 3 free cloud AI providers as fallback routes in ProxyPilot
- **FR-002**: System MUST store all free provider API keys in gopass and inject them via Salt Jinja templates — no plaintext secrets in the repository
- **FR-003**: System MUST support OpenAI-compatible API endpoints (`/v1/chat/completions`) for all free providers, as ProxyPilot's routing depends on this protocol
- **FR-004**: System MUST implement cascading fallback: primary paid providers → high-quality cloud free models → smaller cloud free models → local Ollama → error. Free providers are accessed via dedicated `fallback-*` aliases (not via paid model names), so they are only reachable when AI tools are explicitly configured to use fallback aliases. Emergency-only activation is enforced at the client configuration level — AI tools use `fallback-*` models only when their primary model requests fail.
- **FR-005**: System MUST automatically skip providers returning errors (HTTP 429 rate limit, 401 auth failure, 5xx server error) and try the next provider in the chain
- **FR-006**: System MUST be deployable via a single `salt-call` / `just` apply — no manual steps beyond initial gopass secret provisioning
- **FR-007**: System MUST preserve existing ProxyPilot functionality — all current paid provider routes continue working unchanged
- **FR-008**: System MUST define free provider configurations in a Salt data file (`states/data/`) following the existing data-driven pattern used by `installers.yaml` and `versions.yaml`
- **FR-009**: System MUST map free provider models to ProxyPilot route aliases so existing AI tools do not need reconfiguration
- **FR-010**: System MUST configure ProxyPilot's `request-retry` and `max-retry-credentials` parameters to retry failed free provider API calls (3 attempts, 10s max interval), enabling automatic failover across providers sharing the same alias
- **FR-011**: System MUST expose free provider metrics (fallback activation count, per-provider error rates, Ollama usage) in the existing Grafana dashboard so the operator can monitor fallback health and diagnose paid provider outages

### Key Entities

- **Free Provider**: A cloud AI service offering a free tier with OpenAI-compatible API. Attributes: name, base URL, available models, rate limits (RPM/RPD/TPM), API key reference (gopass path)
- **Fallback Chain**: An ordered list of providers tried in sequence when higher-priority providers fail. Attributes: priority order, quality tier, health status. Activation mode: emergency-only (triggers only when all paid providers are unavailable). Final tier: local Ollama (zero network dependency).
- **Route Alias**: A mapping from a ProxyPilot-facing model name to a provider-specific model identifier. Allows AI tools to request a generic model name while ProxyPilot routes to the best available provider

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When the primary paid provider is unavailable, AI tool requests receive a response from a free fallback provider within 30 seconds of the original request
- **SC-002**: The system maintains at least 3 independent free provider routes, ensuring that the probability of total fallback failure (all free providers down simultaneously) is minimal
- **SC-003**: Adding or removing a free provider requires changes to at most 2 files (data file + gopass secret) with no code modifications
- **SC-004**: All free provider configurations deploy successfully via `just` (Salt apply) with zero manual post-apply steps
- **SC-005**: The fallback system operates with zero ongoing monetary cost — all free provider tiers require no credit card and no payment
- **SC-006**: Operator can determine within 1 minute whether the system is currently operating on fallback providers, and which specific provider is serving requests, via the Grafana dashboard

## Assumptions

- ProxyPilot v0.3.0-dev-0.40 (current version) supports configuring multiple backend providers with fallback routing — this is evidenced by the existing config structure with multiple provider sections and retry/rotation settings
- Free provider API keys can be obtained through self-service signup (no approval process) and stored in gopass
- Free tier rate limits (as of March 2026) are sufficient for intermittent fallback usage — this is not intended to replace paid providers for daily use, only for availability during outages
- The Google Cloud TOS-blocked account issue is unrelated — free providers use separate accounts and services
- OpenAI-compatible API format is the standard integration point — providers not supporting this format are excluded
- Some free providers may use submitted data for model training; this is an accepted trade-off for emergency fallback availability
- Ollama models referenced in `free_providers.yaml` (qwen3.5:27b, qwen2.5-coder:7b, qwen3:14b) are already pulled locally via `states/ollama.sls` — no additional model pulls are needed for the fallback chain

## Recommended Free Providers

Based on research (March 2026), the following providers are recommended for initial configuration:

| Priority | Provider | Key Models | Daily Limits | No Credit Card |
|----------|----------|-----------|--------------|----------------|
| 1 | Groq | Llama 3.3 70B, Qwen3 32B, Llama 4 Scout | 1K RPD, 100K-500K TPD | Yes |
| 2 | Cerebras | Qwen3 235B, Llama 3.1 8B | 1M tokens/day | Yes |
| 3 | OpenRouter | Qwen3 Coder 480B, free model auto-route | 200 RPD per model | Yes |
| 4 | SambaNova | Llama 3.1 405B, Llama 3.3 70B | 10-20 RPM | Yes |

All four cloud providers offer OpenAI-compatible endpoints and require no credit card for signup.

Excluded: Mistral (blocks signups from Russia).

| 5 | Ollama (local) | Models already pulled locally | No limits (GPU-bound) | N/A (local) |

Ollama serves as the absolute last-resort tier — always available, zero network dependency, but limited by local GPU capacity and model size.
