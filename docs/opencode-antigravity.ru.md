# OpenCode Antigravity Auth Plugin

## Obzor

[opencode-antigravity-auth](https://github.com/NoeFabris/opencode-antigravity-auth) — plugin dlia OpenCode,
kotoryi daet dostup k modeliam Claude i Gemini cherez Google Antigravity OAuth.
Ispolzuet kvoty Google IDE, pozvoliaia rabotat s Claude Opus 4.6 i Gemini 3.1 Pro
bez priamykh API-kliuchei.

**Status: OTKLIUCHEN** — osnovnoi akkaunt Google (`serg.zorg@gmail.com`) zablokirovan za narushenie ToS.
Dlia povtornogo vkliucheniia trebuetsia novyi akkaunt Google.

## Zablokirovannyi akkaunt

| Pole | Znachenie |
|---|---|
| Email | `serg.zorg@gmail.com` |
| Proekt | `rising-fact-p41fc` |
| Oshibka | 403 — "This service has been disabled in this account for violation of Terms of Service" |
| Data blokirovki | Do 2026-03-07 |

Eto tot zhe akkaunt, kotoryi blokiruet marshruty Gemini/Antigravity v ProxyPilot.
Apelliatsiia podana, no ne rassmotrena.

**Ne pytaites ispolzovat etot akkaunt** — on vsegda budet vozvrashchat 403 na endpointakh Antigravity.

## Preduprezhdenie o ToS

Google aktivno blokiruet akkaunty, ispolzuiushchie proksi Antigravity ili neofitsialnye plaginy.
Ispolzovanie etogo plagina neset risk blokirovki akkaunta.
Ne ispolzuite akkaunt Google s vazhnymi dannymi (Drive, Gmail i t.d.).

## Kak vkliuchit (s novym akkauntom)

### 1. Dobavit plugin v opencode.json

Otredaktiruire `dotfiles/dot_config/opencode/opencode.json`:

```json
{
  "plugin": ["opencode-antigravity-auth@latest"],
  "enabled_providers": ["openai", "google"],
  "provider": {
    "google": {
      "models": {
        "antigravity-gemini-3-pro": {
          "name": "Gemini 3 Pro (Antigravity)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingLevel": "low" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-gemini-3.1-pro": {
          "name": "Gemini 3.1 Pro (Antigravity)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingLevel": "low" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-gemini-3-flash": {
          "name": "Gemini 3 Flash (Antigravity)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "minimal": { "thinkingLevel": "minimal" },
            "low": { "thinkingLevel": "low" },
            "medium": { "thinkingLevel": "medium" },
            "high": { "thinkingLevel": "high" }
          }
        },
        "antigravity-claude-sonnet-4-6": {
          "name": "Claude Sonnet 4.6 (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "antigravity-claude-opus-4-6-thinking": {
          "name": "Claude Opus 4.6 Thinking (Antigravity)",
          "limit": { "context": 200000, "output": 64000 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] },
          "variants": {
            "low": { "thinkingConfig": { "thinkingBudget": 8192 } },
            "max": { "thinkingConfig": { "thinkingBudget": 32768 } }
          }
        },
        "gemini-2.5-flash": {
          "name": "Gemini 2.5 Flash (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-2.5-pro": {
          "name": "Gemini 2.5 Pro (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3-flash-preview": {
          "name": "Gemini 3 Flash Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65536 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3-pro-preview": {
          "name": "Gemini 3 Pro Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3.1-pro-preview": {
          "name": "Gemini 3.1 Pro Preview (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        },
        "gemini-3.1-pro-preview-customtools": {
          "name": "Gemini 3.1 Pro Preview Custom Tools (Gemini CLI)",
          "limit": { "context": 1048576, "output": 65535 },
          "modalities": { "input": ["text", "image", "pdf"], "output": ["text"] }
        }
      }
    }
  }
}
```

### 2. Udalit starye dannye akkaunta

```bash
rm ~/.config/opencode/antigravity-accounts.json
```

### 3. Avtorizovat novyi akkaunt Google

```bash
opencode auth login
# Vybrat: Google -> OAuth with Google (Antigravity)
# Zavershit avtorizatsiiu v brauzere s NOVYM akkauntom (ne serg.zorg@gmail.com)
```

### 4. Primenit konfiguratsiiu i proverit

```bash
chezmoi apply ~/.config/opencode/opencode.json
opencode run "Hello" --model=google/antigravity-claude-opus-4-6-thinking --variant=max
```

## Dostupnye modeli

**Kvota Antigravity** (pul Google IDE):
- `antigravity-gemini-3-pro` / `antigravity-gemini-3.1-pro` — varianty: low, high
- `antigravity-gemini-3-flash` — varianty: minimal, low, medium, high
- `antigravity-claude-sonnet-4-6` — bez variantov
- `antigravity-claude-opus-4-6-thinking` — varianty: low (8K biudzhet), max (32K biudzhet)

**Kvota Gemini CLI** (otdelnyi pul):
- `gemini-2.5-flash`, `gemini-2.5-pro`
- `gemini-3-flash-preview`, `gemini-3-pro-preview`
- `gemini-3.1-pro-preview`, `gemini-3.1-pro-preview-customtools`

## Faily konfiguratsi

| Fail | Naznachenie |
|---|---|
| `~/.config/opencode/opencode.json` | Osnovnoi konfig (plugin + opredeleniia modelei) |
| `~/.config/opencode/antigravity-accounts.json` | Akkaunty OAuth i tokeny |
| `~/.config/opencode/antigravity.json` | Nastroiki plagina |
| `~/.config/opencode/antigravity-logs/` | Logi otladki |

## Ustranenie nepoladok

**403 "service disabled"**: Akkaunt Google zablokirovan za narushenie ToS. Udalite `antigravity-accounts.json` i avtorizuites s drugim akkauntom.

**Sbros vsego sostoianiia**: `rm ~/.config/opencode/antigravity-accounts.json ~/.config/opencode/antigravity.json`

**Rotatsiia neskolkikh akkauntov**: Plugin podderzhivaet neskolko akkauntov. Zapustite `opencode auth login` snova dlia dobavleniia. Rotatsiia avtomaticheskaia pri dostizhenii limita.
