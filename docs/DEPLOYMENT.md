# Deployment Guide

Complete instructions for deploying and maintaining this Salt configuration on a Fedora Atomic workstation.

---

## First-Time Deployment

### Prerequisites

1. **Fresh Fedora Silverblue/Atomic installation** (43+)
   - UEFI boot recommended
   - Internet connection required
   - Sufficient storage: ~50GB for full toolchain + games

2. **SSH access ready** (if deploying remotely)
   ```bash
   ssh user@host
   ```

3. **Yubikey or GPG key** (if using secrets)
   - Required for `gopass` integration
   - See `docs/secrets-scheme.md`

### Setup Steps

#### 1. Clone the repository

```bash
mkdir -p ~/src
cd ~/src
git clone https://github.com/neg-serg/salt.git
cd salt
```

#### 2. Verify system state

```bash
# Check current OS
cat /etc/os-release | grep PRETTY_NAME

# Check SELinux status
getenforce

# Check rpm-ostree status
rpm-ostree status

# Verify Salt is installed (if not, install: rpm-ostree install salt)
salt-call --version
```

#### 3. Run initial Salt apply

```bash
# Dry-run to see what will change (recommended first)
sudo salt-call -l debug state.apply test=True

# Apply for real (this takes 20-60 minutes depending on options enabled)
sudo salt-call state.apply
```

**Note**: First apply rebuilds system entirely. Be patient.

#### 4. Handle gopass secrets (if needed)

If you use secret management (dotfiles, API keys, etc.):

```bash
# Ensure gopass is available and configured
gopass ls

# If secrets are missing, import them
gpg --import /path/to/gpg/key.asc
gopass config core.autoimport true
```

#### 5. Post-deployment manual steps

Some things cannot be automated:

- **Browser extensions**: Open Floorp → Extensions → install manually from extension IDs in `docs/`
- **SSH keys**: Copy `~/.ssh/` if migrating from another machine
- **Wireless networks**: NetworkManager will prompt, connect to your WiFi
- **Flatpak setup**: First Flatpak launch may show permission dialogs—allow them
- **Yubikey PIN**: Tap Yubikey if gpg-agent prompts for it

#### 6. Verify everything is working

```bash
# Check services are running
systemctl --user status chezmoi
systemctl --user status gpg-agent

# Verify custom RPMs are installed
rpm -q $(cat build/versions.yaml | grep '^\s*[a-z]' | cut -d: -f1)

# Test network functionality
ping 8.8.8.8
curl https://www.google.com

# Check desktop is responsive
hyprctl clients
```

---

## Updates

### Regular Updates (Weekly)

```bash
# Update package lists and installed packages
sudo rpm-ostree upgrade

# Update Flatpak apps
flatpak update -y

# Update user-level tools (chezmoi, cargo, pip, etc.)
chezmoi update
cargo install-update -a
pip install --user --upgrade pip
```

### Full Salt State Reapply

When configuration changes are pulled:

```bash
cd ~/src/salt
git pull origin main

# Test changes first
sudo salt-call state.apply test=True

# Apply if satisfied
sudo salt-call state.apply
```

### Rebuild Custom RPMs

If RPM sources change or versions are pinned:

```bash
cd ~/src/salt
sudo salt-call state.apply build_rpms

# Watch build progress (monitor memory usage)
watch -n 1 'podman ps -a'
```

---

## Troubleshooting

### "Salt State Failed" or "State Returned Non-Zero Exit Code"

**1. Get more details:**
```bash
sudo salt-call -l debug state.apply <state_name>
```

**2. Check which specific sub-state failed:**
```bash
# Look for lines starting with "FAILED:"
sudo salt-call state.apply 2>&1 | grep -i "failed\|error"
```

**3. Common causes:**
- Network timeout → retry after a few minutes
- Missing secret → check gopass is working: `gopass ls`
- SELinux denial → check `sudo ausearch -m AVC | grep -i <service>`
- Package dependency conflict → check `rpm-ostree status`

### "podman: command not found" or "image not found"

podman is containerized by rpm-ostree. Access via:

```bash
# Inside a toolbox environment
toolbox run podman ps

# Or enable permanently
rpm-ostree install podman
rpm-ostree apply-live  # if available
```

### "gpg-agent: multiple agents detected" or "pinentry timeout"

See `docs/GPG-SETUP.md`. Quick fix:

```bash
# Kill rogue daemons
pkill -9 gpg-agent scdaemon

# Reset to systemd-managed socket
systemctl --user restart gpg-agent.socket
```

### "rpm-ostree: No space left on device"

Clean up old deployments:

```bash
# Show all deployments
rpm-ostree status

# Remove old ones (keep last 2-3)
rpm-ostree cleanup -m

# Manual cleanup
sudo du -sh /var/lib/rpm-ostree/*
sudo du -sh /ostree/deploy/fedora/var/*
```

### "Flatpak app won't launch" or "Permission denied"

Flatpak sandboxing is intentionally strict. Fix:

```bash
# Reset Flatpak permissions for an app
flatpak permission-reset <app.id>

# Launch with debugging
flatpak run --devel <app.id>

# Check logs
journalctl -xe | grep flatpak
```

### "systemd service won't start" (chezmoi, gpg-agent, etc.)

```bash
# Check service status
systemctl --user status <service>

# See logs
journalctl --user -xu <service> -n 50

# Try restarting
systemctl --user restart <service>

# Check socket if applicable
systemctl --user status <service>.socket
```

### "SELinux is blocking this" (denials in journalctl)

Check context:

```bash
# See recent denials
sudo ausearch -m AVC -ts recent | tail -20

# Suggest policy fix
sudo ausearch -m AVC -ts recent | audit2allow -a

# Apply suggested policy
sudo ausearch -m AVC -ts recent | audit2allow -a -M <module_name>
sudo semodule -i <module_name>.pp
```

See `docs/SELinux.md` for more details.

### "RPM build failed" (custom packages)

```bash
# Check build logs
cat /tmp/salt-build-rpms-parallel.sh.log

# Watch live build
sudo salt-call state.apply build_rpms -l debug 2>&1 | tail -50

# Inspect build container
podman run --rm -it registry.fedoraproject.org/fedora-toolbox:43 bash
```

---

## Design Rationale

### Why rpm-ostree instead of traditional package manager?

rpm-ostree provides **immutable system + layered packages**:
- Base OS is atomic (either works or rolls back)
- Custom packages layer on top (can break, but base stays intact)
- Critical for workstation stability when testing custom builds
- Enables `--apply-live` for instant updates without reboot

**Trade-off**: Some packages can't be installed (version conflicts with base image). Workaround: Flatpak or custom RPM.

### Why Salt instead of Ansible/NixOS/other?

- **Salt = local execution** (no SSH/network needed for local machine)
- **Event-driven** (watches files, triggers on change)
- **Powerful templating** (Jinja2 for config generation)
- **Idempotent by design** (safe to run repeatedly)
- **Custom macros** (reusable patterns for workstation-specific patterns)

**Trade-off**: Salt has a learning curve. Benefits scale over time as config grows.

### Why systemd user services instead of system-wide?

- **Per-user isolation**: Services run as unprivileged user (neg)
- **Easy enable/disable**: `systemctl --user enable <service>`
- **Automatic cleanup**: Socket activation avoids zombie processes
- **Works in Flatpak**: User services respect sandbox boundaries

### Why gopass for secrets instead of pass/bitwarden/1password?

- **GPG-based** (no separate subscription or cloud service)
- **Git-backed** (secrets in version control, encrypted)
- **Yubikey support** (hardware security key for offline-capable auth)
- **Works with Salt** (can template dotfiles with `gopass show`)

See `docs/secrets-scheme.md` for full setup.

### Why Flatpak for GUI apps?

- **Sandboxing** (isolates apps from system)
- **Easy updates** (independent of OS updates)
- **No permission surprises** (controlled via Flatseal)
- **Works on Atomic** (doesn't require layering)

**Trade-off**: Flatpak apps are slightly slower and can't access all system resources.

### Why systemd socket activation for some services?

Reduces resource usage:  daemon only starts when needed. Examples: gpg-agent.socket, dbus.socket

### Why bind mounts instead of symbolic links?

Symbolic links don't work reliably across Fedora Atomic updates. Bind mounts are atomic and survive rebases.

---

## Monitoring

### Check system health

```bash
# Overall status
rpm-ostree status

# Active services
systemctl --user status

# Resource usage
btop

# Disk usage
ncdu ~
du -sh /var/mnt/*
```

### Check for errors

```bash
# Recent journal errors
journalctl -p err -n 20

# User service errors
journalctl --user -p err -n 20

# SELinux denials
sudo ausearch -m AVC -ts recent | head -10
```

---

## Backup and Recovery

### Backup important data

```bash
# Backup dotfiles (managed by chezmoi)
chezmoi data > ~/.chezmoi-backup.json

# Backup secrets (if using gopass)
gopass export > ~/.gopass-backup.gpg

# Backup system config
sudo rpm-ostree status > ~/system-state.txt
```

### Rollback to previous deployment

```bash
# List deployments
rpm-ostree status

# Reboot into previous (select at bootloader)
# Or manually:
rpm-ostree rollback

# Reboot
sudo systemctl reboot
```

---

## Performance Tuning

### If system feels slow

```bash
# Check for I/O bottlenecks
iotop -o

# Check CPU usage
perf top

# Check memory pressure
free -h
cat /proc/pressure/memory

# Monitor network
nethogs
```

### Common optimizations (already enabled)

- vm.swappiness tuned
- I/O scheduler set to deadline/none
- CPU governor set to performance/powersave (laptop)
- zswap enabled for memory compression

See `states/sysctl.sls` for details.

---

## Getting Help

1. **Check documentation first:**
   - `docs/CLAUDE.md` — architecture overview
   - `docs/nixos-config-migration.md` — what's been migrated from NixOS
   - `docs/SELinux.md` — SELinux troubleshooting
   - `docs/secrets-scheme.md` — gopass + Yubikey setup

2. **Check logs:**
   ```bash
   journalctl -xe | tail -50
   sudo journalctl -xe | tail -50
   ```

3. **Check the Salt state that failed:**
   ```bash
   grep -r "state_id" states/*.sls | grep -i <failing_thing>
   ```

4. **Run with debug output:**
   ```bash
   sudo salt-call -l debug state.apply <specific_state>
   ```

---

## Maintenance Schedule

| Frequency | Task |
|-----------|------|
| **Daily** | None required (auto-services handle most) |
| **Weekly** | `rpm-ostree upgrade && flatpak update` |
| **Monthly** | Review `journalctl` for patterns; clean up old deployments |
| **Quarterly** | Review and update custom RPM versions |
| **As-needed** | Pull latest Salt config, test, apply |

---

_Last updated: 2026-02-13_
