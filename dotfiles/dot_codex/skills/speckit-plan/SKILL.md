---
name: speckit-plan
description: Use the repository's Specify planning workflow to generate implementation-planning artifacts from an existing feature spec on a Specify feature branch.
---

# Speckit Plan

Use this skill when the user wants implementation planning for a repo that uses `.specify/`, especially when they refer to `speckit.plan`, a feature branch, or generating `plan.md`, `research.md`, `data-model.md`, `contracts/`, or `quickstart.md`.

## Preconditions

- The repository has a `.specify/` directory.
- A Specify feature already exists and `spec.md` is present.
- You are on the corresponding feature branch, or the repo is otherwise configured so `.specify/scripts/bash/setup-plan.sh` can resolve the active feature.

If these conditions are not met, stop and explain what is missing.

## Workflow

1. From the repo root, run:

```bash
.specify/scripts/bash/setup-plan.sh --json
```

Parse the JSON output and capture:

- `FEATURE_SPEC`
- `IMPL_PLAN`
- `SPECS_DIR`
- `BRANCH`

2. Read:

- `FEATURE_SPEC`
- `.specify/memory/constitution.md`
- `.specify/templates/plan-template.md`
- `IMPL_PLAN` after it is created/copied by the setup script

3. Fill `IMPL_PLAN` using the repository's planning workflow:

- Complete the Technical Context section.
- Mark unknown technical details as `NEEDS CLARIFICATION`.
- Fill the Constitution Check before research.
- Identify open questions, dependencies, integrations, and risky choices.

4. Produce Phase 0 research in `research.md` under `SPECS_DIR`:

- Resolve every `NEEDS CLARIFICATION`.
- For each important decision, document:
  - `Decision`
  - `Rationale`
  - `Alternatives considered`

5. Produce Phase 1 design artifacts under `SPECS_DIR`:

- `data-model.md`
- `contracts/` when the feature exposes interfaces to users or other systems
- `quickstart.md`

6. Update agent context for Codex:

```bash
.specify/scripts/bash/update-agent-context.sh codex
```

7. Re-check the Constitution Check after design artifacts are complete.

## Boundaries

- Stop after planning artifacts are complete.
- Do not implement production code as part of this skill.
- Do not create `tasks.md` unless the user explicitly asks for the tasks phase.
- Use absolute paths when reporting generated artifacts.
- Treat unresolved critical clarifications or failed constitutional gates as errors.

## Expected Output

Report:

- active branch
- absolute path to `plan.md`
- generated artifact paths
- any blocked items that prevented a complete plan
