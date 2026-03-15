# pyinfra Project Health Assessment

Evaluation of pyinfra as a long-term replacement for Salt in the context of a single-workstation configuration management setup.

## pyinfra Overview

| Metric | Value |
|---|---|
| GitHub stars | ~4,900 |
| Forks | ~467 |
| Contributors | ~30 |
| Open issues | 211 |
| License | MIT |
| Language | Python 3 |
| Latest release | v3.7 (March 2026) |
| Release cadence | ~6-8 weeks (v3.2 Jan 2025 -> v3.7 Mar 2026) |
| Built-in operations | ~44 modules |
| Pacman support | Yes (`pacman.packages()`) |
| AUR support | None built-in |
| Documentation | Good for basics, thin on advanced patterns |
| Bus factor | 1 (Nick Barrett / Fizzadar) |

## Salt Overview (for comparison)

| Metric | Value |
|---|---|
| GitHub stars | ~15,300 |
| Forks | ~5,572 |
| Contributors | 500+ |
| Open issues | ~4,000+ |
| License | Apache 2.0 |
| Language | Python 3 |
| Latest release | 3006.x LTS (Sulfur) |
| Release cadence | Slowed significantly post-VMware/Broadcom acquisition |
| Built-in state modules | ~400+ |
| Pacman support | Yes (`pkg.installed` with pacman provider) |
| AUR support | None built-in |
| Documentation | Extensive but aging, some modules underdocumented |
| Bus factor | Team (VMware/Broadcom), but organizational neglect evident |

## Detailed Comparison

### Community and Governance

**pyinfra**: Single-maintainer project. Nick Barrett (Fizzadar) is the sole core developer, handling nearly all PRs, issues, and releases. The 30 contributors are mostly occasional drive-by fixes. No corporate sponsor, no foundation, no governance model. The project survives on one person's sustained motivation.

**Salt**: Backed by VMware (now Broadcom) but showing signs of neglect post-acquisition. The community salt-extensions effort attempts to modularize, but progress is slow. Core team has shrunk. Despite this, the installed base and corporate deployments provide inertia that prevents abandonment.

### Module Coverage

**pyinfra (44 modules)**:
- `apt`, `apk`, `brew`, `choco`, `dnf`, `emerge`, `pacman`, `pkg` (BSD), `pkgin`, `xbps`, `zypper` -- package managers
- `files`, `git`, `pip`, `npm`, `gem` -- common deploy operations
- `systemd`, `upstart`, `init`, `launchd` -- service management
- `server` (users, groups, hostname, crontab, reboot, shell)
- `puppet`, `mysql`, `postgresql`, `lxd`, `docker`, `kubernetes` -- specialized

**Salt (400+ modules)**:
- All of the above plus: `mount`, `kmod`, `timezone`, `locale`, `btrfs`, `firewalld`, `dconf`, `selinux`, `grub`, `alternatives`, and hundreds more
- Each module handles idempotency internally

**Gap analysis for this project**:
- `mount.mounted` / `mount.fstab_present` -- pyinfra has no mount module; must use `server.shell()`
- `kmod.present` -- no kernel module operation; must use shell commands
- `timezone.system` -- no timezone operation; must use shell commands
- `file.replace` (regex in-file editing) -- pyinfra `files.line` exists but is simpler; complex regex replacements need `server.shell()`
- `service.masked` -- pyinfra `systemd.service` supports enable/disable/start/stop but not mask
- `user.present` with uid/gid/groups -- pyinfra `server.user()` covers this adequately
- `file.managed` with `template: jinja` + `context:` -- pyinfra uses Python f-strings or Jinja2 via `files.template()`
- No equivalent to Salt's `stateful: True`, `prereq:`, or `watch:` requisite system

### Idempotency Model

**Salt**: Built into every state module. `pkg.installed` checks before installing. `file.managed` compares checksums. `service.running` checks status. The developer declares desired state; Salt figures out what to change.

**pyinfra**: Operations are also idempotent by default (e.g., `pacman.packages()` checks before installing). However, `server.shell()` commands are NOT idempotent -- they run every time unless wrapped with `_if`/`_unless` conditionals. Since many Salt modules have no pyinfra equivalent, this project would rely heavily on `server.shell()`, losing idempotency guarantees unless manually reimplemented.

### Execution Model

**Salt**: Compiles state tree into a DAG, resolves `require:`/`watch:`/`prereq:` dependencies, then executes in dependency order. States can run in parallel when independent.

**pyinfra**: Executes operations top-to-bottom in declaration order. No dependency DAG. No built-in parallel execution of operations. Operations across multiple hosts run in parallel, but that is irrelevant for a single-workstation setup. This is a fundamental architectural difference -- the entire require/watch system would need manual ordering.

### Extensibility

**Salt**: Custom states via Python modules, custom grains, custom execution modules. Heavy framework overhead.

**pyinfra**: Custom deploys via `@deploy` decorator on regular Python functions. Lightweight, Pythonic. Significantly easier to write custom operations. This is pyinfra's strongest advantage -- the macro system (1,338 lines of Jinja) would become clean Python functions.

## Risk Assessment

### Risks of Adopting pyinfra

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| **Bus factor = 1**: Project abandoned if Nick Barrett stops maintaining | Critical | Medium (5yr horizon) | MIT license allows forking; codebase is small (~15k lines) and comprehensible |
| **No AUR support**: Must implement paru/makepkg wrapper from scratch | Medium | Certain | Write custom `@deploy` function (~50 lines); manageable |
| **No mount/kmod/timezone modules**: Many states need raw shell commands | Medium | Certain | Wrap in reusable `@deploy` functions; loses type safety |
| **No watch/onchanges equivalent**: Service restarts on config change require manual tracking | High | Certain | pyinfra's `_if_changed` callback partially covers this; will need custom handler pattern |
| **Thin advanced documentation**: Complex patterns (secrets, conditional deploys, cross-deploy deps) underdocumented | Medium | Certain | Read source code; pyinfra codebase is small and readable |
| **Migration effort**: 264-380 hours estimated (see complexity-matrix.md) | High | Certain | Phased migration possible; run both systems during transition |
| **No `parallel: True` for operations**: Sequential-only execution on single host | Low | Certain | Acceptable for workstation use; parallel downloads can use Python `concurrent.futures` |
| **Small ecosystem**: 44 modules vs 400+; fewer community recipes | Medium | Certain | Most missing modules are wrappable with `server.shell()` |

### Risks of Staying on Salt

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| **VMware/Broadcom neglect**: Reduced investment, slower releases, community erosion | High | High | Salt-extensions community effort; but momentum is uncertain |
| **Python dependency weight**: Salt pulls in ~50+ Python packages; venv management overhead | Low | Certain | Already managed; not a blocker |
| **Jinja complexity**: 1,338 lines of macros are effectively a DSL on top of YAML; hard to debug, test, or refactor | High | Certain | This is the pain driving the migration investigation |
| **Masterless mode second-class**: Salt optimized for master-minion; masterless has rough edges (slow startup, redundant features loaded) | Medium | Certain | Tolerable but adds ~3s to every `salt-call` |
| **Overkill for single host**: Salt's 400+ modules, pillar system, mine, reactor -- none needed for one workstation | Low | Certain | Unused features are harmless but add cognitive load |

## Conclusion

### pyinfra is a viable but risky choice

**In favor of migration**:
- Python-native deploys eliminate the Jinja macro nightmare (1,338 lines of Jinja -> clean Python functions)
- Dramatically simpler mental model (top-to-bottom execution vs DAG resolution)
- Easier to test (pytest vs Salt's test.ping/test=True)
- Lightweight runtime (~15k lines vs Salt's ~500k lines)
- MIT license; small enough to fork and maintain if abandoned

**Against migration**:
- Bus factor of 1 is a real long-term risk on a 5-10 year horizon
- Missing modules (mount, kmod, timezone, service.masked) mean more raw shell commands
- No reactive system (watch/onchanges) -- must manually track config-changed-then-restart patterns
- 264-380 hours of migration effort for a system that currently works
- pyinfra's sequential execution model cannot express the parallel download patterns currently used

### Recommendation

**Do not migrate yet.** The migration cost (7-10 weeks) is not justified by the current pain level. Instead:

1. **Monitor pyinfra's contributor growth** through 2026. If the contributor count rises above 10 active developers or a second core maintainer emerges, the bus-factor risk drops significantly.
2. **Prototype one Hard-complexity state** (e.g., `dns.sls` or `openclaw_agent.sls`) in pyinfra to validate assumptions about watch/onchanges handling, secret management, and idempotency.
3. **Consider pyinfra if Salt's Broadcom situation worsens** -- if Salt misses two consecutive LTS releases or the community salt-extensions effort stalls, the calculus changes.
4. **Reduce Jinja complexity incrementally** within Salt by extracting macro logic into Salt custom execution modules (pure Python), which would also make a future pyinfra migration easier.
