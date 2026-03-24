# Zapret2 Safe Rollout

## Overview

This repository manages `zapret2` in a safe-rollout mode first. The default workflow prepares package, config, unit, and helper artifacts without changing live traffic handling.

## Default Boundary

- `prepare`: describe the managed Zapret2 surface
- `preflight`: collect prerequisites, conflicts, and rollback inputs
- `preview`: show what activation would touch
- `activate`: gated behind explicit approval and still review-first by default

Until explicit approval is granted, the workflow must not:

- enable or start `zapret2.service`;
- change live firewall or packet-handling state; or
- stop or reconfigure existing proxy or network components automatically.

## Managed Artifacts

- Salt state: `states/zapret2.sls`
- Data model: `states/data/zapret2.yaml`
- Config template: `states/configs/zapret2.conf.j2`
- Unit template: `states/units/zapret2.service.j2`
- Rollout helper: `scripts/zapret2-rollout.sh`

## Safe Workflow

Render and inspect the managed surface first:

```bash
just validate
scripts/zapret2-rollout.sh prepare
scripts/zapret2-rollout.sh preflight
scripts/zapret2-rollout.sh preview
```

Expected result:

- planned artifacts are listed;
- prerequisites and conflicts are reported;
- rollback inputs are captured in report form; and
- activation remains blocked without explicit approval.

## Approval Gate

Activation requires an explicit approval file and rollback inputs file. Without them, `scripts/zapret2-rollout.sh activate` fails closed.

Even with approval present, the default review flow still avoids live execution unless the operator deliberately invokes the activation path with the required inputs.

## Notes

- The current branch prepares `zapret2` ownership and validation safely.
- Live rollout should be performed only after you explicitly confirm that destructive changes are allowed.
