# Feature Specification: Expand Free Fallback Provider Pool

**Feature Branch**: `004-expand-free-providers`
**Created**: 2026-03-08
**Status**: Draft
**Input**: User description: "Расширить пул бесплатных fallback-провайдеров ProxyPilot: китайские провайдеры (SiliconFlow, DeepSeek, Zhipu GLM), другие бесплатные API (Perplexity, Kilo Code и др.)"

## Clarifications

### Session 2026-03-08

- Q: Should DeepSeek be included despite having trial credits (5M tokens/30 days) rather than a permanent free tier? → A: Include but mark as optional — add to data file but document that it requires trial signup and may eventually cost money. Operator can choose to enable/disable by provisioning or omitting the gopass key.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add China-Based Free Providers for Sanctions-Resistant Fallback (Priority: P1)

The existing free fallback chain (Groq, Cerebras, OpenRouter, Ollama) relies on 3 US-based cloud providers that could become inaccessible from Russia at any time due to OFAC/EU sanctions enforcement — the same mechanism that already eliminated Mistral (France) and SambaNova (US). Chinese providers are not subject to Western sanctions and provide a geopolitically independent fallback path, dramatically reducing the risk of total cloud provider loss.

**Why this priority**: This is the core value — adding providers that are structurally resistant to the same failure mode (sanctions/geo-blocking) that already eliminated 2 of the original 5 cloud providers. SiliconFlow offers a permanent free tier with 20+ models, making it the highest-value addition.

**Independent Test**: Can be fully tested by adding SiliconFlow credentials to gopass, running the bootstrap script, and verifying that `fallback-large` requests can be served by SiliconFlow models through ProxyPilot.

**Acceptance Scenarios**:

1. **Given** SiliconFlow is configured as a free provider, **When** an AI tool sends a request to a `fallback-*` alias, **Then** ProxyPilot may route the request to SiliconFlow and return a valid response
2. **Given** all US-based cloud providers (Groq, Cerebras, OpenRouter) become inaccessible, **When** a request is sent to any `fallback-*` alias, **Then** the Chinese providers and local Ollama still respond — zero total cloud outage
3. **Given** a fresh deployment with new providers, **When** Salt applies the config, **Then** the new providers appear in ProxyPilot's active routes alongside existing ones

---

### User Story 2 - Increase Alias Redundancy (Priority: P2)

Currently some aliases have thin coverage: `fallback-small` has only 1 cloud provider (Cerebras), `fallback-code` has 1 cloud provider (OpenRouter), and `fallback-medium` has 1 cloud provider (Groq). Adding new providers increases redundancy across all aliases, reducing the chance that any single alias becomes unavailable when a single provider fails.

**Why this priority**: Thin alias coverage is a reliability gap. If Cerebras goes down, `fallback-small` has zero cloud providers. Adding SiliconFlow (which has free small models like Qwen2.5-7B) immediately fills this gap.

**Independent Test**: Can be tested by verifying that each `fallback-*` alias resolves to at least 2 cloud providers after the new providers are added, then blocking one and confirming the other still responds.

**Acceptance Scenarios**:

1. **Given** new providers are configured, **When** checking alias coverage, **Then** every `fallback-*` alias has at least 2 cloud providers (not counting Ollama)
2. **Given** one cloud provider for `fallback-small` fails, **When** a request arrives, **Then** another cloud provider serves it without falling to Ollama

---

### User Story 3 - Maintain Zero-Cost Operation (Priority: P1)

All new providers must operate at zero monetary cost. Providers with trial credits (DeepSeek's 5M token trial) are acceptable only as supplementary additions alongside truly permanent-free providers. The system must function correctly using only permanent-free providers.

**Why this priority**: Co-equal with US1 because the core constraint of the fallback system is zero cost. Any provider requiring payment defeats the purpose.

**Independent Test**: Can be tested by verifying that all configured providers either have a permanent free tier or that the system functions correctly with only the permanent-free subset.

**Acceptance Scenarios**:

1. **Given** all configured providers, **When** reviewing their billing status, **Then** the system maintains at least 4 providers with permanent free tiers requiring no credit card
2. **Given** a trial-credit provider (DeepSeek) exhausts its credits, **When** fallback requests arrive, **Then** they route to permanent-free providers without interruption

---

### Edge Cases

- What happens when a Chinese provider's API endpoint changes or becomes unavailable? ProxyPilot's retry mechanism routes to the next provider in the alias pool. The operator updates the endpoint in the data file and re-applies Salt.
- What happens when DeepSeek's trial credits expire? Requests to DeepSeek return 402/429; ProxyPilot routes around it to other providers. The operator can optionally top up credits at DeepSeek's extremely low rates ($0.28/M tokens) or remove the provider.
- What happens when SiliconFlow's free model list changes? The operator updates model names in the data file and runs `just`. ProxyPilot logs warnings about failed model routes for deprecated models.
- How does the system handle providers requiring Chinese phone verification? Only providers with email/international signup are included. If a provider changes its signup requirements, it is documented as excluded.
- What happens when a free provider starts training on submitted data? This is documented as a known trade-off — the fallback is emergency-only, not default routing. Data sensitivity is lower for emergency requests.
- What if the total number of providers causes ProxyPilot startup slowdown? ProxyPilot handles provider configuration at startup only; the runtime routing overhead is per-request with O(1) alias lookup. 6-8 providers is well within normal operating range.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST add SiliconFlow as a free fallback provider with at least 3 model mappings covering `fallback-large`, `fallback-small`, and `fallback-code` aliases
- **FR-002**: System MUST add DeepSeek as an optional fallback provider with at least 2 model mappings covering `fallback-code` and `fallback-large` aliases. DeepSeek is included in the data file but documented as optional — it requires trial signup (5M tokens/30 days) and may cost money after trial expiry ($0.28/M tokens). The operator can enable or disable it by provisioning or omitting the gopass key. The system MUST function correctly without DeepSeek configured.
- **FR-003**: System MUST store all new provider API keys in gopass and inject them via the existing Salt/bootstrap mechanism — no plaintext secrets in the repository
- **FR-004**: System MUST follow the existing data-driven pattern: add entries to `states/data/free_providers.yaml` with no code modifications required
- **FR-005**: System MUST preserve existing provider configurations unchanged — all current free and paid routes continue working
- **FR-006**: System MUST ensure every `fallback-*` alias has at least 2 cloud providers after the expansion
- **FR-007**: System MUST be deployable via the existing `scripts/bootstrap-free-providers.sh` + `just` workflow with no new tooling
- **FR-008**: System MUST update the Grafana dashboard provider error rate panel to include new providers
- **FR-009**: System MUST update documentation (`docs/proxypilot-free-fallback.md` + `.ru.md`, `docs/secrets-scheme.md` + `.ru.md`) to reflect new providers

### Key Entities

- **Free Provider**: Extended with new entries. Attributes unchanged: name, base URL, available models, API key reference (gopass path), priority. New providers slot into existing priority ordering between OpenRouter (3) and Ollama (last).
- **Fallback Alias**: Same 4 aliases (`fallback-large`, `fallback-code`, `fallback-medium`, `fallback-small`). Coverage increases with new provider entries.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The system maintains at least 5 independent cloud free provider routes (up from 3), ensuring that total fallback failure probability is further reduced
- **SC-002**: Every `fallback-*` alias has at least 2 cloud providers, eliminating single-provider alias vulnerability
- **SC-003**: At least 2 of the configured cloud providers are China-based companies (not subject to Western sanctions), providing a geopolitically independent fallback path
- **SC-004**: Adding the new providers requires changes to at most 2 existing files (data file + gopass secrets) with no code modifications — same ease of deployment as the original feature
- **SC-005**: All new providers operate at zero ongoing monetary cost (permanent free tiers or negligible cost below $1/year at emergency-only usage levels)

## Assumptions

- SiliconFlow's permanent free tier for small models (Qwen2.5-7B-Instruct, Llama-3.1-8B, GLM-4-9B-Chat) remains available as of March 2026 and requires no credit card for signup
- DeepSeek's API signup works from Russia via email registration (confirmed working as of March 2026)
- SiliconFlow's endpoint (`api.siliconflow.cn/v1`) is accessible from Russia without VPN — Chinese companies are not subject to Western sanctions
- The existing bootstrap script and Salt template handle additional providers without modifications — the data-driven architecture supports arbitrary provider count
- Ollama models referenced in free_providers.yaml are already pulled locally via states/ollama.sls — no additional model pulls needed
- Chinese providers' data privacy policies (potential training on submitted data) are an accepted trade-off for emergency fallback availability

## Research Results: Provider Evaluation

Based on research (March 2026), the following providers were evaluated:

### Recommended for Addition

| Priority | Provider | Key Free Models | Free Tier Type | No Credit Card | Russia Access |
|----------|----------|----------------|----------------|----------------|---------------|
| 3.5 | SiliconFlow | Qwen2.5-7B-Instruct, Llama-3.1-8B, GLM-4-9B-Chat | Permanent (20+ free models) | Yes | Yes (Chinese) |
| 3.7 | DeepSeek | DeepSeek-V3.2, DeepSeek-R1 | Trial (5M tokens/30d) + $0.28/M after | Yes | Yes (confirmed) |

### Excluded After Research

| Provider | Reason for Exclusion |
|----------|---------------------|
| Perplexity AI | No free API tier — paid-only, requires credit card |
| Kilo Code | IDE extension, not a standalone API provider |
| Chutes AI | Free tier being discontinued (Feb 2026) |
| Together AI | Requires $5 minimum purchase + credit card |
| Fireworks AI | $1 starter credit only, 10 RPM — too restrictive |
| Novita AI | $0.50 starter credit only, not permanent free |
| Moonshot/Kimi | Requires $1 minimum recharge |
| Baidu ERNIE | No OpenAI-compatible API, China-domestic focused |
| Alibaba DashScope | Trial only (1M tokens/model, 90 days), not permanent |
| Zhipu AI/Z.AI (GLM) | Trial credits only, not permanent free tier |
