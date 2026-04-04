# gh-issues-export

Экспорт GitHub issues (с комментариями) в отдельные Markdown-файлы с YAML-метаданными, оптимизированный для RAG.

## Использование

```
gh-issues-export [OPTIONS] <owner/repo | github-url>
```

## Опции

| Опция | По умолчанию | Описание |
|-------|-------------|----------|
| `--output DIR` | `./gh-issues/<owner>-<repo>/` | Директория для экспорта |
| `--state STATE` | `all` | Фильтр: `open`, `closed`, `all` |
| `--full` | выкл | Полный ре-экспорт |
| `--help` | — | Показать справку |

## Примеры

```zsh
# Экспорт всех issues
gh-issues-export cli/cli

# Только открытые issues в свою папку
gh-issues-export --state open --output ~/rag-data/cli-cli cli/cli

# Принудительный полный экспорт
gh-issues-export --full cli/cli

# Полный URL тоже работает
gh-issues-export https://github.com/cli/cli
```

## Формат вывода

Каждый issue — отдельный Markdown-файл с YAML frontmatter:

```markdown
---
number: 42
title: "Пример issue"
state: open
author: octocat
labels: ["bug", "urgent"]
assignees: ["octocat"]
created_at: "2026-01-15T10:30:00Z"
updated_at: "2026-03-20T14:22:00Z"
url: "https://github.com/owner/repo/issues/42"
comments_count: 3
---

Тело issue...

## Comment by contributor1 on 2026-01-16T08:00:00Z

Текст комментария...
```

## Инкрементальные обновления

Скрипт сохраняет `.export-meta.json` в директории экспорта. При повторном запуске скачиваются только обновлённые issues. Флаг `--full` для полного перескачивания.

## Интеграция с RAG

Формат вывода напрямую совместим с:
- **LangChain**: `DirectoryLoader("./gh-issues/owner-repo/", glob="*.md")`
- **LlamaIndex**: `SimpleDirectoryReader("./gh-issues/owner-repo/")`

## Зависимости

- `gh` (GitHub CLI, авторизованный)
- `jq`

## Коды выхода

| Код | Значение |
|-----|----------|
| 0 | Успех |
| 1 | Неверные аргументы |
| 2 | Не найден gh/jq или не авторизован |
| 3 | Репозиторий не найден |
| 4 | Ошибка сети/API |
