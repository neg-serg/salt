# Ростер провайдеров генерации изображений

Генерация изображений через бесплатные AI-провайдеры с приоритетным переключением.

## Обзор

Ростер генерации изображений следует той же схеме, что и `free_providers.yaml` для текстового AI:
- Провайдеры описаны в `states/data/image_providers.yaml`
- API-ключи берутся из gopass с AWK-fallback
- Конфиг рендерится Salt в `~/.config/image-gen/providers.yaml`
- CLI-обёртка `gen-image` читает конфиг и вызывает провайдеров напрямую

## Провайдеры

| Провайдер | Тип API | Бесплатный тариф | Приоритет |
|-----------|---------|-------------------|-----------|
| Together AI | OpenAI-совместимый | $100 кредитов + 3 мес. FLUX.1-schnell | 1 |
| Hugging Face | HF Inference API | ~несколько сотен запросов/час | 2 |
| Cloudflare Workers AI | REST API | 100 тыс. запросов/день | 3 |
| Локальный ComfyUI | Workflow API | Без ограничений (локальный GPU) | 5 |

## Настройка

### 1. Добавить API-ключи

```bash
# Интерактивная настройка (пропускает существующие)
scripts/bootstrap-image-providers.sh

# Проверить наличие ключей
scripts/bootstrap-image-providers.sh --check
```

Или вручную:

```bash
gopass insert api/together-ai    # https://api.together.xyz/settings/api-keys
gopass insert api/huggingface    # https://huggingface.co/settings/tokens
gopass insert api/cloudflare-ai  # https://dash.cloudflare.com/profile/api-tokens
```

### 2. Применить Salt-стейт

```bash
just apply image_generation
```

### 3. Генерация изображений

```bash
gen-image "кот сидит на радуге"
gen-image "киберпанк город ночью" --model flux-quality
gen-image "горный пейзаж" --size 1024x768 --output ~/pic/landscape.png
```

## Алиасы моделей

Алиасы группируют одинаковые возможности разных провайдеров для переключения:

| Алиас | Описание | Провайдеры |
|-------|----------|------------|
| `flux-fast` | Быстрая генерация FLUX | Together AI, Hugging Face, Cloudflare, ComfyUI |
| `flux-quality` | Качественная генерация FLUX | Together AI, Hugging Face |
| `sdxl` | Stable Diffusion XL | Together AI, Hugging Face, Cloudflare, ComfyUI |

## Добавление провайдера

1. Редактировать `states/data/image_providers.yaml`:

```yaml
  - name: "new-provider"          # уникальное имя
    base_url: "https://api.example.com/v1"
    api_type: "openai"            # openai | huggingface | cloudflare | comfyui
    gopass_key: "api/new-provider"
    priority: 4                   # уникальный приоритет (1=высший)
    models:
      - name: "model-id"
        alias: "flux-fast"        # общий алиас для переключения
```

2. Добавить API-ключ:

```bash
gopass insert api/new-provider
```

3. Применить:

```bash
just apply image_generation
```

## Устранение неполадок

| Проблема | Решение |
|----------|---------|
| `gen-image: command not found` | Выполнить `just apply image_generation` или `chezmoi apply` |
| `config not found` | Выполнить `just apply image_generation` |
| Все провайдеры не работают | Проверить `scripts/bootstrap-image-providers.sh --check` |
| Cloudflare 403 | Указать `account_id` в `image_providers.yaml` |
| ComfyUI таймаут | Убедиться, что ComfyUI запущен на порту 8188 |

## Файлы

| Файл | Назначение |
|------|------------|
| `states/data/image_providers.yaml` | Ростер провайдеров (редактируйте этот файл) |
| `states/configs/image-gen-providers.yaml.j2` | Шаблон конфига |
| `states/image_generation.sls` | Salt-стейт |
| `scripts/bootstrap-image-providers.sh` | Настройка API-ключей |
| `dotfiles/dot_local/bin/executable_gen-image` | CLI-обёртка |
| `~/.config/image-gen/providers.yaml` | Рендеренный конфиг (не редактировать) |
