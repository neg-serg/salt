# Quickstart: Salt Package Management

## Prerequisites

- CachyOS workstation with Salt masterless setup working (`just` succeeds)
- `pacman-contrib` installed (provides `pactree` for the reduction pass)
- Existing Salt states render cleanly

## Step 1: Generate the initial package list

```bash
# Run the analysis tool to capture current system state
./scripts/pkg-snapshot.zsh

# Output: states/data/packages.yaml
# Review the generated file — packages are categorized automatically
```

The script:
1. Captures `pacman -Qqe` (all explicitly-installed packages)
2. Parses existing `.sls` files to find packages managed by domain states
3. Excludes domain-managed packages from the output
4. Auto-categorizes remaining packages by pacman groups and repo metadata
5. Writes `states/data/packages.yaml`

## Step 2: Review and adjust categories

Open `states/data/packages.yaml` and verify:
- Packages are in sensible categories
- Empty categories have comments explaining they're managed by domain states
- AUR packages are correctly identified under the `aur:` key

## Step 3: Optional — run the reduction pass

```bash
# Identify packages that could be removed from the explicit list
./scripts/pkg-snapshot.zsh --reduce

# Review each candidate — don't blindly remove
# Edit packages.yaml to remove confirmed redundancies
```

## Step 4: Verify Salt renders cleanly

```bash
# Dry-run Salt to confirm the new state works
just

# The new packages.sls should show all packages as already installed
# (since we captured the current state, nothing should change)
```

## Step 5: Day-to-day package management

```bash
# Install a new package: add it to packages.yaml, then apply
echo "  - new-package" >> states/data/packages.yaml  # (under the right category)
just

# Check for drift (packages installed outside Salt)
./scripts/pkg-drift.zsh
```

## File Map

| File | Purpose |
|------|---------|
| `states/data/packages.yaml` | Declared package list (source of truth) |
| `states/packages.sls` | Salt state that installs packages from the YAML |
| `scripts/pkg-snapshot.zsh` | One-shot tool: captures current system → YAML |
| `scripts/pkg-drift.zsh` | Diagnostic: compares declared vs actual state |
