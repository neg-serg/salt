# Zapret2 Safe Rollout

## Overview

This repository manages `zapret2` in a safe-rollout mode first. The default workflow prepares package, config, unit, and helper artifacts without changing live traffic handling.

## Default Boundary

- `prepare`: describe the managed Zapret2 surface
- `preflight`: collect prerequisites and conflicts
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
- approval requirements are captured in report form; and
- activation remains blocked without explicit approval.

## Operator Runbook

Non-destructive review path:

```bash
scripts/zapret2-rollout.sh grant-approval --operator "$USER" --reason "approved after preflight review"
scripts/zapret2-rollout.sh preview
scripts/zapret2-rollout.sh smoke
```

## Activation Modes

Two activation styles are supported after explicit approval:

1. Separate live activation after the rollout artifacts are already present.
2. Activation within the same rollout window that applies Zapret2-managed artifacts and then starts the unit as the final operator step.

Separate live activation entrypoint:

```bash
sudo systemctl start zapret2.service
```

Activation during the rollout window:

```bash
scripts/salt-apply.sh zapret2
sudo systemctl start zapret2.service
```

If the host feature flag is already enabled in `states/data/hosts.yaml`, the same activation window can use the full host rollout instead:

```bash
scripts/salt-apply.sh
sudo systemctl start zapret2.service
```

The Salt rollout still prepares package, config, helper, and unit first. The traffic-affecting step remains the explicit service start, whether it happens immediately after the rollout or later in a separate window.

Post-activation verification:

```bash
scripts/zapret2-rollout.sh smoke
```

## Approval Gate

Activation requires an explicit approval file. Without it, `scripts/zapret2-rollout.sh activate` fails closed.

Even with approval present, the default review flow still avoids live execution unless the operator deliberately invokes the activation path with the required inputs. This applies both to separate live activation and to activation performed in the same rollout window as `scripts/salt-apply.sh`.

## Testing and Verification

### Verify active profiles after service start

```bash
# Check nfqws2 is running with Kyber QUIC profiles:
pgrep -a nfqws2 | grep -c kyber        # expect ≥ 2

# Check Google TLS fake profile is deployed:
grep tls_clienthello_www_google_com.bin /opt/zapret2/config

# Check new hostlist domains:
grep yt3.ggpht.com /opt/zapret2/ipset/zapret-hosts-user.txt
```

### Manual connectivity checks

```bash
# YouTube HTTPS (TLS 1.3):
curl -m 10 -sI https://www.youtube.com | head -3

# YouTube HTTP/3 (QUIC) — requires curl with HTTP/3 support:
curl --http3 -m 10 -sI https://www.youtube.com | head -3
```

### Full automated strategy scan (blockcheck2)

```bash
# Scan all strategies for youtube.com in batch mode:
sudo BATCH=1 DOMAINS=youtube.com /opt/zapret2/blockcheck2.sh

# Test only QUIC/HTTP3:
sudo BATCH=1 DOMAINS=youtube.com ENABLE_HTTP=0 ENABLE_HTTPS_TLS12=0 ENABLE_HTTPS_TLS13=0 ENABLE_HTTP3=1 /opt/zapret2/blockcheck2.sh

# Save output to log:
sudo BATCH=1 DOMAINS=youtube.com /opt/zapret2/blockcheck2.sh | tee /tmp/blockcheck.log
```

## Notes

- The current branch prepares `zapret2` ownership and validation safely.
- Live rollout should be performed only after you explicitly confirm that destructive changes are allowed.
- Approval management, smoke checks, and preview output are implemented in the helper.
