# Quickstart: Expand Free Fallback Provider Pool

## Prerequisites

- 003-proxypilot-free-fallback fully deployed and working
- ProxyPilot running with existing 4 providers (Groq, Cerebras, OpenRouter, Ollama)
- `scripts/bootstrap-free-providers.sh` functional

## Step 1: Sign Up for New Providers

### SiliconFlow (mandatory)

1. Go to https://cloud.siliconflow.cn/
2. Register with email, GitHub, or Google OAuth
3. Navigate to https://cloud.siliconflow.cn/account/ak
4. Create API key (starts with `sk-`)
5. Store: `gopass insert api/siliconflow`

### DeepSeek (optional)

1. Go to https://platform.deepseek.com
2. Register with email or Google login
3. Navigate to API Keys section
4. Create API key (starts with `sk-`)
5. Store: `gopass insert api/deepseek`

## Step 2: Deploy

```bash
# Seed new keys into ProxyPilot config
scripts/bootstrap-free-providers.sh

# Deploy via Salt
just

# Restart ProxyPilot
systemctl --user restart proxypilot
```

## Step 3: Verify

```bash
# Check all keys present
scripts/bootstrap-free-providers.sh --check

# Test SiliconFlow via fallback-small (SiliconFlow is one of 2 providers for this alias)
API_KEY=$(gopass show -o api/proxypilot-local)

# Send multiple requests to see round-robin
for i in 1 2 3 4 5; do
  curl -sS --max-time 30 http://127.0.0.1:8317/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d '{"model":"fallback-small","messages":[{"role":"user","content":"Hi"}],"max_tokens":5}' \
    | grep -o '"model":"[^"]*"'
done
# Should show both cerebras (llama3.1-8b) and siliconflow (Qwen/Qwen3.5-4B)

# Test DeepSeek (only if key provisioned)
curl -sS --max-time 30 http://127.0.0.1:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"model":"fallback-code","messages":[{"role":"user","content":"Write hello world in Python"}],"max_tokens":20}' \
  | grep -o '"model":"[^"]*"'
# May show deepseek-chat, qwen/qwen3-coder-480b-a35b:free, Qwen/Qwen2.5-Coder-7B-Instruct, or qwen2.5-coder:7b

# Verify existing paid routes unaffected
curl -sS --max-time 30 http://127.0.0.1:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"model":"claude-sonnet-4-6","messages":[{"role":"user","content":"Hi"}],"max_tokens":5}' \
  | grep -o '"model":"[^"]*"'
# Should return claude-sonnet-4-6 (Anthropic OAuth)
```

## Step 4: Monitor

Open Grafana at http://127.0.0.1:3000 → ProxyPilot dashboard → "Fallback Providers" row.
New providers (siliconflow, deepseek) should appear in the error rate timeseries panel.
