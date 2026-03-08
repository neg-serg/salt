# Research: Expand Free Fallback Provider Pool

## R1: SiliconFlow API Integration

**Decision**: Use SiliconFlow as primary new provider with 4 model mappings across all fallback aliases.

**Rationale**: Only Chinese provider with a truly permanent free tier (20+ models at zero cost). OpenAI-compatible API. Global Traffic Manager endpoint accessible internationally. No credit card required. Chinese company — not subject to Western sanctions.

**Alternatives considered**:
- Zhipu AI/Z.AI (GLM): Trial credits only, not permanent free — rejected
- Alibaba DashScope: Trial only (1M tokens/model, 90 days) — rejected
- Moonshot/Kimi: Requires $1 minimum recharge — rejected

**API Details**:
- Endpoint: `https://api.siliconflow.cn/v1`
- Auth: `Authorization: Bearer <key>` (standard OpenAI format)
- Signup: https://cloud.siliconflow.cn/ (email, GitHub, or Google OAuth)
- API key management: https://cloud.siliconflow.cn/account/ak
- Rate limits (free tier): 1,000 RPM, 50,000 TPM (no documented daily caps)

**Free Model Selection**:

| Alias | Model ID | Params | Rationale |
|-------|----------|--------|-----------|
| fallback-large | `deepseek-ai/DeepSeek-R1-Distill-Qwen-7B` | 7B | Best quality free model — R1 reasoning distilled, 93.9% on MATH-500, 128K context |
| fallback-code | `Qwen/Qwen2.5-Coder-7B-Instruct` | 7B | Purpose-built code model from Qwen 2.5 Coder family |
| fallback-medium | `Qwen/Qwen3-8B` | 8.2B | Newest general model, thinking/non-thinking mode, strong all-rounder |
| fallback-small | `Qwen/Qwen3.5-4B` | 4B | Smallest free model, latest Qwen 3.5 generation, 262K context |

**Caveats**:
- Higher latency from outside China (servers in China, GTM routing helps but doesn't eliminate)
- Model churn: SiliconFlow regularly discontinues models — list should be verified periodically
- Rate limits are per-model ceiling; specific models may have lower limits

---

## R2: DeepSeek API Integration (Optional)

**Decision**: Include DeepSeek as optional provider with 2 model mappings. Operator enables by provisioning gopass key.

**Rationale**: Confirmed accessible from Russia. Top-tier code and reasoning models. 5M token trial covers months of emergency usage. After trial: $0.28/M tokens (negligible at emergency-only rates). Chinese company — sanctions-resistant.

**Alternatives considered**:
- Making DeepSeek mandatory: Rejected — trial credits expire, violates zero-cost principle as a hard requirement
- Excluding DeepSeek entirely: Rejected — too valuable as a Russia-confirmed, high-quality fallback

**API Details**:
- Endpoint: `https://api.deepseek.com` (note: no `/v1` suffix — DeepSeek uses `https://api.deepseek.com` as base URL, but it maps `/v1/chat/completions` correctly)
- Auth: `Authorization: Bearer <key>` (standard OpenAI format)
- Signup: https://platform.deepseek.com (email or Google login, works from Russia)
- Rate limits: No hard RPM limit documented; extremely generous for the price tier

**Model Selection**:

| Alias | Model ID | Rationale |
|-------|----------|-----------|
| fallback-code | `deepseek-chat` | DeepSeek-V3.2 — strongest code model in the free/cheap tier |
| fallback-large | `deepseek-reasoner` | DeepSeek-R1 — top reasoning model, chain-of-thought |

---

## R3: Excluded Providers (Full Analysis)

| Provider | Reason | Evidence |
|----------|--------|----------|
| Perplexity AI | No free API tier at all | Paid-only, credit card required for API key |
| Kilo Code | IDE extension, not an API provider | Routes to other providers internally |
| Chutes AI | Free tier being discontinued Feb 2026 | Moving to subscription model |
| Together AI | $5 minimum purchase + credit card | Hard paywall from signup |
| Fireworks AI | Only $1 starter credit, 10 RPM limit | Too restrictive for fallback use |
| Novita AI | Only $0.50 starter credit | Not permanent free |
| Moonshot/Kimi | $1 minimum recharge required | Not zero-cost |
| Baidu ERNIE | No OpenAI-compatible API | Proprietary format, China-domestic focused |
| Alibaba DashScope | Trial only (90 days) | Not permanent, expires |
| Zhipu AI/Z.AI | Trial credits only | Not permanent free tier |

---

## R4: Priority Ordering After Expansion

Current: Groq (1) → Cerebras (2) → OpenRouter (3) → Ollama (4)

After expansion:

| Priority | Provider | Type | Sanctions Risk |
|----------|----------|------|---------------|
| 1 | Groq | US cloud, permanent free | Medium (US company) |
| 2 | Cerebras | US cloud, permanent free | Medium (US company) |
| 3 | OpenRouter | US aggregator, permanent free | Low (aggregator, Russian traffic documented) |
| 4 | SiliconFlow | Chinese cloud, permanent free | None (Chinese company) |
| 5 | DeepSeek | Chinese cloud, optional/trial | None (Chinese company) |
| 6 | Ollama | Local, always available | None (local) |

**Rationale for SiliconFlow at priority 4 (after OpenRouter)**:
- Higher latency from Russia (servers in China) compared to US providers
- OpenRouter has lower latency and broader model selection via auto-routing
- SiliconFlow provides the sanctions-resistant safety net if US providers go down
- Ollama remains last as the zero-network-dependency guarantee

**Rationale for DeepSeek at priority 5 (before Ollama)**:
- Optional provider — only active if operator provisions the key
- Higher quality models than Ollama (DeepSeek-V3.2 >> Qwen3.5:27b local)
- If key is not provisioned, ProxyPilot simply skips it (AWK returns empty string)
