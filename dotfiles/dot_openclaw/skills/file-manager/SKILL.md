---
name: file-manager
description: Browse, search, read, and manage files within allowed directory paths
requires:
  bins: ["ls", "find", "cat", "cp", "mv", "realpath"]
allowed-tools:
  - "Bash(ls:*)"
  - "Bash(find:*)"
  - "Bash(cat:*)"
  - "Bash(cp:*)"
  - "Bash(mv:*)"
  - "Bash(realpath:*)"
  - "Bash(mkdir:*)"
  - "Bash(wc:*)"
  - "Bash(file:*)"
  - "Bash(du:*)"
  - "Read"
os: ["linux"]
---

# File Manager

Browse, search, read, and manage files within allowed directory paths.

## CRITICAL: Path Validation

Before ANY file operation, you MUST validate the path:

1. Run `realpath <path>` to resolve the absolute path (follows symlinks, resolves `..`)
2. Verify the resolved path starts with one of the allowed prefixes listed below
3. If the path is outside allowed directories, REFUSE the operation with a clear explanation of which directories are allowed
4. This prevents symlink escape attacks — a symlink inside `~/doc` could point to `/etc/shadow`

```bash
# Example: always validate before operating
resolved=$(realpath "/home/alice/doc/notes/../../../etc/passwd")
# resolved = /etc/passwd → DENIED (not in allowed paths)
```

## Allowed Paths

| Path | Contents |
|---|---|
| `~/doc` | Documents |
| `~/dw` | Downloads |
| `~/music` | Music library |
| `~/pic` | Pictures |
| `~/vid` | Videos |
| `~/src` | Source code |
| `/tmp` | Temporary files |

These are the ONLY directories you may access. Everything else is off-limits.

## Operations

### List directory contents

```bash
ls -lahF <path>
```

### Search by filename

```bash
find <path> -name "PATTERN" -maxdepth 5
```

### Search by file content

```bash
grep -rl "PATTERN" <path> --include="*.txt" --include="*.md"
```

### Read file

For small files:

```bash
cat <path>
```

For larger or structured files, use the `Read` tool instead.

### File info (MIME type detection)

```bash
file <path>
```

### Directory size

```bash
du -sh <path>
```

### Count files in a directory

```bash
find <path> -type f | wc -l
```

### Copy a file or directory

```bash
cp <src> <dst>
```

Validate BOTH source and destination paths before executing.

### Move or rename

```bash
mv <src> <dst>
```

Validate BOTH source and destination paths before executing.

### Create a directory

```bash
mkdir -p <path>
```

## Safety Rules

- **NEVER use `rm`** — deletion is not supported through this skill. If the user asks to delete something, explain that this skill does not support deletion.
- **ALWAYS confirm before move/copy operations** — show the user the resolved source and destination paths and ask for confirmation before executing.
- **NEVER follow symlinks outside allowed paths** — always check with `realpath` first. If a symlink resolves to a path outside the allowed directories, refuse the operation.
- **Warn before reading large files** — if a file is larger than 1MB, inform the user of the file size and ask whether they want to proceed.
- **Do not cat binary files** — run `file <path>` first to check the MIME type. If the file is binary (not text/*), tell the user the file type instead of dumping binary data.
- **NEVER access these paths**, even if the user requests it:
  - `/etc/` — system configuration
  - `/root/` — root home directory
  - `/home/*/.*` — dotfiles and hidden directories in any home
  - `/var/` — system variable data
  - `/usr/` — system binaries and libraries
