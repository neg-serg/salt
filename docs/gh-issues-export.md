# gh-issues-export

Export GitHub issues (with comments) as individual Markdown files with YAML frontmatter, optimized for RAG ingestion.

## Usage

```
gh-issues-export [OPTIONS] <owner/repo | github-url>
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `--output DIR` | `./gh-issues/<owner>-<repo>/` | Output directory |
| `--state STATE` | `all` | Filter: `open`, `closed`, `all` |
| `--full` | off | Force full re-export |
| `--help` | — | Show help |

## Examples

```zsh
# Export all issues
gh-issues-export cli/cli

# Export only open issues to custom dir
gh-issues-export --state open --output ~/rag-data/cli-cli cli/cli

# Force full re-export (ignore incremental timestamp)
gh-issues-export --full cli/cli

# Accept full GitHub URL
gh-issues-export https://github.com/cli/cli
```

## Output format

Each issue becomes a Markdown file with YAML frontmatter:

```markdown
---
number: 42
title: "Example issue"
state: open
author: octocat
labels: ["bug", "urgent"]
assignees: ["octocat"]
milestone: "v2.0"
created_at: "2026-01-15T10:30:00Z"
updated_at: "2026-03-20T14:22:00Z"
url: "https://github.com/owner/repo/issues/42"
comments_count: 3
---

Issue body...

## Comment by contributor1 on 2026-01-16T08:00:00Z

Comment body...
```

## Incremental updates

The script stores a `.export-meta.json` in the output directory. On subsequent runs, only issues updated since the last export are fetched. Use `--full` to override.

## RAG integration

Output is directly compatible with:
- **LangChain**: `DirectoryLoader("./gh-issues/owner-repo/", glob="*.md")`
- **LlamaIndex**: `SimpleDirectoryReader("./gh-issues/owner-repo/")`

## Dependencies

- `gh` (GitHub CLI, authenticated)
- `jq`

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments |
| 2 | Missing gh/jq or not authenticated |
| 3 | Repository not found |
| 4 | Network/API error |
