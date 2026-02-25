# TODO

## Music analysis pipeline (essentia + annoy)

Scripts `music-highlevel`, `music-similar`, `music-index` require:
- `essentia` (provides `streaming_extractor_music`) — not in Arch repos, needs AUR or custom PKGBUILD
- `python-annoy` — approximate nearest neighbors library, pip or AUR

Create a dedicated Salt state (`music_analysis.sls` or extend `installers.sls`) that:
1. Builds/installs `essentia` via paru or PKGBUILD
2. Installs `python-annoy` via pip_pkg macro
3. Guards both with idempotency checks

## Diagnose greetd login delay after reboot

The greeter Hyprland hangs ~5s during shutdown (segfaults in `libaquamarine.so`).
Debug logging has been added — after reboot:

1. Apply salt state first (deploys debug configs):
   ```
   just apply greetd
   ```

2. Reboot, log in normally.

3. Check the login timeline:
   ```
   journalctl -b -o short-monotonic | rg '(greetd|session-wrapper|AQ_|aquamarine)'
   ```

4. Full chain with monotonic timestamps (look for the gap between auth and session start):
   ```
   journalctl -b -o short-monotonic | rg '(greetd|session-wrapper|Hyprland|coredump)' | rg -v 'xdg-desktop-portal'
   ```

5. Check if the greeter Hyprland still crashes:
   ```
   coredumpctl list Hyprland
   ```

### What was added
- `AQ_TRACE=1` + `debug { enable_stdout_logs = true }` in greeter Hyprland config
- `RUST_LOG=debug` in greetd systemd override
- `logger` timestamps in `/etc/greetd/session-wrapper`

### After diagnosis
Remove debug logging: delete `debug {}` and `AQ_TRACE` from `configs/greetd-hyprland.conf.j2`,
delete `units/greetd-debug-override.conf`, remove the `unit_override` call from `greetd.sls`.

## Nyxt browser packaging

`nyxt-bin` — binary packaging for the Nyxt browser. Needs investigation:
current AUR package may be sufficient, or may need custom PKGBUILD.
