# Watch/Onchanges Migration to pyinfra

Analysis of all 15 watch/onchanges directives and their pyinfra equivalents using `OperationMeta.did_change`.

## Background

Salt's `watch` and `onchanges` are **reactive requisites** -- they trigger actions only when upstream states report changes:
- **`watch`**: re-runs the state (for `service.running`, this means restart) when any watched state changes.
- **`onchanges`**: runs the state *only* when upstream states changed (noop otherwise).

pyinfra's equivalent is `OperationMeta.did_change` -- a boolean property on the return value of any operation. The caller must explicitly capture the return value, check `did_change`, and conditionally run follow-up operations.

---

## Directive Inventory

| # | Location | Type | Trigger | Effect |
|---|----------|------|---------|--------|
| 1 | `_macros_service.jinja` (udev_rule) | onchanges | file (udev rule) | udevadm reload |
| 2 | `_macros_service.jinja` (unit_override) | onchanges | file (drop-in) | systemctl daemon-reload |
| 3 | `_macros_service.jinja` (user_service_file) | onchanges | file (user unit) | systemctl --user daemon-reload |
| 4 | `_macros_service.jinja` (user_unit_override) | onchanges | file (user drop-in) | systemctl --user daemon-reload |
| 5 | `_macros_service.jinja` (service_with_unit) | onchanges | file (unit + companion) | systemctl daemon-reload |
| 6 | `_macros_service.jinja` (service_with_unit) | watch | file (unit + config) | service restart |
| 7 | `_macros_service.jinja` (ensure_running) | watch | file (config files) | service restart |
| 8 | `sysctl.sls` | onchanges | file (sysctl config) | sysctl --system |
| 9 | `network.sls` | onchanges | file (bridge netdev) | firewall-cmd reload |
| 10 | `installers.sls` | onchanges | cmd (qmk udev rules) | udevadm reload |
| 11 | `floorp.sls` | onchanges | file + cmd (user.js + extensions) | delete extensions.json |
| 12 | `amnezia.sls` | onchanges | file (binary) | version verification |
| 13 | `dns.sls` (resolved) | watch | file (resolved config) | restart systemd-resolved |
| 14 | `dns.sls` (adguardhome via service_with_unit) | watch | file (unit + config) | restart adguardhome |
| 15 | `services.sls` (transmission) | watch | file (3 settings files) | restart transmission |

---

## Detailed Migration

### 1. udev_rule macro -- onchanges: file -> udevadm reload

**Salt (5 lines in rendered YAML):**
```yaml
custom_udev_rules:
  file.managed:
    - name: /etc/udev/rules.d/99-custom.rules
    - source: salt://configs/udev-custom.rules
    - mode: '0644'

custom_udev_rules_reload:
  cmd.run:
    - name: udevadm control --reload-rules && udevadm trigger
    - onchanges:
      - file: custom_udev_rules
```

**pyinfra (6 lines):**
```python
rule = files.put(
    name="Deploy udev rule",
    dest="/etc/udev/rules.d/99-custom.rules",
    src="configs/udev-custom.rules", mode="0644",
)
if rule.did_change:
    server.shell(name="Reload udev rules", commands=["udevadm control --reload-rules && udevadm trigger"])
```

**Verbosity**: 5 -> 6 lines (+1, +20%)

---

### 2. unit_override macro -- onchanges: file -> daemon-reload

**Salt (7 lines in rendered YAML):**
```yaml
netdata_override:
  file.managed:
    - name: /etc/systemd/system/netdata.service.d/override.conf
    - source: salt://units/netdata-override.conf
    - makedirs: True
    - mode: '0644'

netdata_override_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: netdata_override
```

**pyinfra (7 lines):**
```python
override = files.put(
    name="Deploy netdata override",
    dest="/etc/systemd/system/netdata.service.d/override.conf",
    src="units/netdata-override.conf", mode="0644",
    create_remote_dir=True,
)
if override.did_change:
    server.shell(name="Daemon-reload for netdata", commands=["systemctl daemon-reload"])
```

**Verbosity**: 7 -> 7 lines (+0, 0%)

---

### 3. user_service_file macro -- onchanges: file -> user daemon-reload

**Salt (9 lines in rendered YAML):**
```yaml
mbsync_gmail_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/mbsync-gmail.service
    - source: salt://units/user/mbsync-gmail.service
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True

mbsync_gmail_service_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - onchanges:
      - file: mbsync_gmail_service
```

**pyinfra (12 lines):**
```python
unit = files.put(
    name="Deploy mbsync-gmail user unit",
    dest="/home/neg/.config/systemd/user/mbsync-gmail.service",
    src="units/user/mbsync-gmail.service",
    user="neg", group="neg", mode="0644",
    create_remote_dir=True,
)
if unit.did_change:
    server.shell(
        name="User daemon-reload for mbsync-gmail",
        commands=["systemctl --user daemon-reload"],
        _su_user="neg",
        _env={"XDG_RUNTIME_DIR": "/run/user/1000",
              "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"},
    )
```

**Verbosity**: 9 -> 12 lines (+3, +33%)

---

### 4. user_unit_override macro -- onchanges: file -> user daemon-reload

**Salt (11 lines in rendered YAML):**
```yaml
mpdris2_user_service:
  file.managed:
    - name: /home/neg/.config/systemd/user/mpDris2.service.d/override.conf
    - user: neg
    - group: neg
    - mode: '0644'
    - makedirs: True
    - contents: |
        [Service]
        ExecStart=
        ExecStart=/usr/bin/mpDris2 -p 6600

mpdris2_user_service_daemon_reload:
  cmd.run:
    - name: systemctl --user daemon-reload
    - runas: neg
    - env:
      - XDG_RUNTIME_DIR: /run/user/1000
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/1000/bus
    - onchanges:
      - file: mpdris2_user_service
```

**pyinfra (13 lines):**
```python
from io import StringIO

override_content = "[Service]\nExecStart=\nExecStart=/usr/bin/mpDris2 -p 6600\n"
override = files.put(
    name="Deploy mpDris2 user override",
    dest="/home/neg/.config/systemd/user/mpDris2.service.d/override.conf",
    src=StringIO(override_content),
    user="neg", group="neg", mode="0644",
    create_remote_dir=True,
)
if override.did_change:
    server.shell(
        name="User daemon-reload for mpDris2",
        commands=["systemctl --user daemon-reload"],
        _su_user="neg",
        _env={"XDG_RUNTIME_DIR": "/run/user/1000",
              "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"},
    )
```

**Verbosity**: 11 -> 13 lines (+2, +18%)

---

### 5. service_with_unit macro (daemon-reload) -- onchanges: file -> daemon-reload

**Salt (rendered for loki, 7 lines for the daemon-reload portion):**
```yaml
loki_service:
  file.managed:
    - name: /etc/systemd/system/loki.service
    - mode: '0644'
    - source: salt://units/loki.service

loki_daemon_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: loki_service
```

**pyinfra (7 lines):**
```python
unit = files.put(
    name="Deploy loki.service",
    dest="/etc/systemd/system/loki.service",
    src="units/loki.service", mode="0644",
)
if unit.did_change:
    server.shell(name="Daemon-reload for loki", commands=["systemctl daemon-reload"])
```

**Verbosity**: 7 -> 7 lines (+0, 0%)

---

### 6. service_with_unit macro (running+watch) -- watch: file -> service restart

**Salt (rendered for loki, 10 lines for the running portion):**
```yaml
loki_running:
  service.running:
    - name: loki
    - watch:
      - file: loki_service
      - file: loki_config
    - require:
      - service: loki_enabled
      - cmd: loki_reset_failed
```

**pyinfra (8 lines):**
```python
# Must capture loki_service (from #5 above) and loki_config results upstream
restart_needed = unit.did_change or config.did_change
systemd.service(
    name="Ensure loki running",
    service="loki",
    running=True,
    restarted=restart_needed,
)
```

**pyinfra (with full context showing the upstream capture, 16 lines total):**
```python
unit = files.put(name="Deploy loki.service", dest="/etc/systemd/system/loki.service",
                 src="units/loki.service", mode="0644")
if unit.did_change:
    server.shell(name="Daemon-reload for loki", commands=["systemctl daemon-reload"])

config = files.template(name="Deploy loki config", src="configs/loki.yaml.j2",
                         dest="/etc/loki/local-config.yaml", mode="0644")

systemd.service(name="Enable loki", service="loki", enabled=True)
server.shell(name="Reset failed loki", commands=["systemctl reset-failed loki 2>/dev/null; true"],
             _if=lambda: host.get_fact(SystemdStatus).get("loki", {}).get("SubState") == "failed")

restart = unit.did_change or config.did_change
systemd.service(name="Ensure loki running", service="loki", running=True, restarted=restart)
```

**Verbosity**: 10 -> 16 lines (+6, +60%). The overhead comes from explicit variable capture and the merged daemon-reload + running blocks.

---

### 7. ensure_running macro -- watch: file -> service restart

**Salt (rendered for unbound, 10 lines):**
```yaml
unbound_running:
  service.running:
    - name: unbound
    - watch:
      - file: unbound_config
      - file: unbound_restart_override
    - require:
      - service: unbound_enabled
      - cmd: unbound_reset_failed
```

**pyinfra (9 lines):**
```python
# config_result and override_result must be captured upstream
restart = config_result.did_change or override_result.did_change
server.shell(
    name="Reset failed unbound",
    commands=["systemctl reset-failed unbound 2>/dev/null; true"],
    _if=lambda: host.get_fact(SystemdStatus).get("unbound", {}).get("SubState") == "failed",
)
systemd.service(name="Ensure unbound running", service="unbound",
                running=True, restarted=restart)
```

**Verbosity**: 10 -> 9 lines (-1, -10%). However, the upstream capture adds 2 lines per watched state at the call site.

---

### 8. sysctl.sls -- onchanges: file -> sysctl --system

**Salt (5 lines):**
```yaml
sysctl_config:
  file.managed:
    - name: /etc/sysctl.d/99-custom.conf
    - source: salt://configs/sysctl-custom.conf
    - mode: '0644'

sysctl_apply:
  cmd.run:
    - name: sysctl --system
    - onchanges:
      - file: sysctl_config
```

**pyinfra (5 lines):**
```python
config = files.put(
    name="Deploy sysctl config",
    dest="/etc/sysctl.d/99-custom.conf",
    src="configs/sysctl-custom.conf", mode="0644",
)
if config.did_change:
    server.shell(name="Apply sysctl", commands=["sysctl --system"])
```

**Verbosity**: 5 -> 5 lines (+0, 0%)

---

### 9. network.sls -- onchanges: file -> firewall-cmd reload

**Salt (8 lines):**
```yaml
vm_bridge_firewall:
  cmd.run:
    - name: |
        firewall-cmd --permanent --zone=trusted --add-interface=br0
        firewall-cmd --permanent --zone=trusted --add-service=dhcp
        firewall-cmd --reload
    - shell: /bin/bash
    - onlyif: command -v firewall-cmd
    - onchanges:
      - file: vm_bridge_netdev
```

**pyinfra (9 lines):**
```python
netdev = files.put(
    name="Deploy br0 netdev",
    dest="/etc/systemd/network/10-br0.netdev",
    src=StringIO("[NetDev]\nName=br0\nKind=bridge\n"), mode="0644",
    create_remote_dir=True,
)
if netdev.did_change:
    server.shell(
        name="Configure firewall for br0",
        commands=["""
            firewall-cmd --permanent --zone=trusted --add-interface=br0
            firewall-cmd --permanent --zone=trusted --add-service=dhcp
            firewall-cmd --reload
        """],
        _shell_executable="/bin/bash",
        _if=lambda: host.get_fact(Which, "firewall-cmd") is not None,
    )
```

**Verbosity**: 8 -> 9 lines (+1, +13%). The `onlyif` + `onchanges` combination requires both `_if` and `did_change`, which is more explicit.

---

### 10. installers.sls -- onchanges: cmd -> udevadm reload

**Salt (5 lines):**
```yaml
qmk_udev_rules_reload:
  cmd.run:
    - name: udevadm control --reload-rules
    - onlyif: command -v udevadm >/dev/null 2>&1
    - onchanges:
      - cmd: qmk_udev_rules
```

**pyinfra (5 lines):**
```python
# qmk_rules is the OperationMeta from the http_file() call above
if qmk_rules.did_change:
    server.shell(
        name="Reload udev for QMK rules",
        commands=["udevadm control --reload-rules"],
        _if=lambda: host.get_fact(Which, "udevadm") is not None,
    )
```

**Verbosity**: 5 -> 5 lines (+0, 0%)

**Note**: The upstream state is a `cmd.run` (not `file.managed`), so `did_change` checks whether the command actually executed (vs being skipped by `creates:`). pyinfra's `server.shell()` returns `OperationMeta` with `did_change` reflecting actual execution, so this is equivalent.

---

### 11. floorp.sls -- onchanges: file + cmd (multi-source) -> delete file

**Salt (8+ lines, dynamic based on extension count):**
```yaml
floorp_reset_extensions_json:
  file.absent:
    - name: /home/neg/.floorp/xxx.default/extensions.json
    - onchanges:
      - file: floorp_user_js
      - cmd: floorp_ext_ublock_origin
      - cmd: floorp_ext_bitwarden
      - cmd: floorp_ext_dark_reader
      # ... one per extension
```

**pyinfra (6+ lines):**
```python
# Must capture user_js_result and all extension install results
triggers = [user_js_result] + ext_results  # list of OperationMeta
if any(t.did_change for t in triggers):
    files.file(
        name="Reset Floorp extensions.json",
        path="/home/neg/.floorp/xxx.default/extensions.json",
        present=False,
    )
```

**Verbosity**: 8 -> 6 lines (-2, -25%). Fewer lines because `any()` replaces per-item `onchanges` entries. However, the call site must maintain a list of `OperationMeta` objects from a loop, adding ~3 lines upstream.

**pyinfra (full context with loop, ~12 lines):**
```python
ext_results = []
for ext in floorp_extensions:
    result = server.shell(
        name=f"Install Floorp ext {ext['slug']}",
        commands=[f"curl -fsSL -o '{xpi}.tmp' '...' && mv -f '{xpi}.tmp' '{xpi}'"],
        _su_user="neg",
        _if=lambda: not host.get_fact(File, xpi),
    )
    ext_results.append(result)

if user_js.did_change or any(r.did_change for r in ext_results):
    files.file(name="Reset extensions.json", path="...", present=False)
```

**Verbosity** (full): 8 -> 12 lines (+4, +50%)

---

### 12. amnezia.sls -- onchanges: file -> version verification

**Salt (6 lines per binary, 3 binaries = 18 lines total):**
```yaml
amneziawg_go_verify:
  cmd.run:
    - name: /home/neg/.local/bin/amneziawg-go --version
    - onchanges:
      - file: amneziawg_go_bin

awg_verify:
  cmd.run:
    - name: /home/neg/.local/bin/awg --version
    - onchanges:
      - file: amneziawg_tools_bin

amnezia_vpn_verify:
  cmd.run:
    - name: ldd /home/neg/.local/bin/AmneziaVPN
    - onchanges:
      - file: amnezia_vpn_bin
```

**pyinfra (12 lines):**
```python
verifications = [
    ("amneziawg-go", go_bin_result, "/home/neg/.local/bin/amneziawg-go --version"),
    ("awg", tools_bin_result, "/home/neg/.local/bin/awg --version"),
    ("AmneziaVPN", vpn_bin_result, "ldd /home/neg/.local/bin/AmneziaVPN"),
]
for name, result, cmd in verifications:
    if result.did_change:
        server.shell(name=f"Verify {name}", commands=[cmd])
```

**Verbosity**: 18 -> 12 lines (-6, -33%). The loop is more compact than three separate Salt states. However, each `result` must be captured upstream.

---

### 13. dns.sls (resolved) -- watch: file -> restart systemd-resolved

**Salt (5 lines):**
```yaml
resolved_restart:
  service.running:
    - name: systemd-resolved
    - watch:
      - file: resolved_adguardhome
```

**pyinfra (4 lines):**
```python
# resolved_config is the OperationMeta from file.managed above
systemd.service(
    name="Restart systemd-resolved",
    service="systemd-resolved",
    running=True,
    restarted=resolved_config.did_change,
)
```

**Verbosity**: 5 -> 4 lines (-1, -20%)

---

### 14. dns.sls (adguardhome via service_with_unit) -- watch: file -> restart

**Salt (rendered, 7 lines for the running portion):**
```yaml
adguardhome_running:
  service.running:
    - name: adguardhome
    - watch:
      - file: adguardhome_service
      - file: adguardhome_config
    - require:
      - service: adguardhome_enabled
      - cmd: adguardhome_reset_failed
```

**pyinfra (6 lines):**
```python
restart = unit.did_change or config.did_change
server.shell(
    name="Reset failed adguardhome",
    commands=["systemctl reset-failed adguardhome 2>/dev/null; true"],
    _if=lambda: is_failed("adguardhome"),
)
systemd.service(name="Ensure adguardhome running", service="adguardhome",
                running=True, restarted=restart)
```

**Verbosity**: 7 -> 6 lines (-1, -14%)

---

### 15. services.sls (transmission) -- watch: file x3 -> restart + prereq stop

**Salt (14 lines):**
```yaml
transmission_stop_before_settings_change:
  service.dead:
    - name: transmission
    - prereq:
      - file: transmission_download_dir_setting
      - file: transmission_watch_dir_setting
      - file: transmission_watch_dir_enabled

transmission_restart_after_settings_change:
  service.running:
    - name: transmission
    - watch:
      - file: transmission_download_dir_setting
      - file: transmission_watch_dir_setting
      - file: transmission_watch_dir_enabled
    - require:
      - service: transmission_enabled
      - cmd: transmission_start
```

**pyinfra (14 lines):**
```python
# Capture all three setting file operations
settings_changed = (download_dir.did_change or watch_dir.did_change or watch_enabled.did_change)

# prereq: stop service BEFORE writing settings (if any will change)
# NOTE: pyinfra has NO prereq equivalent -- operations run in definition order.
# We must reorder: stop -> write settings -> restart
if settings_changed:
    systemd.service(name="Stop transmission before settings change",
                    service="transmission", running=False)

# ... settings file operations would go here in pyinfra ...
# (but they already ran above -- this is the two-phase problem!)

if settings_changed:
    systemd.service(name="Restart transmission after settings change",
                    service="transmission", running=True)
```

**Verbosity**: 14 -> 14 lines (+0, 0%)

**CRITICAL NOTE**: Salt's `prereq` directive has **NO pyinfra equivalent**. `prereq` causes Salt to run the dead state *before* the file states that trigger it -- a form of look-ahead. In pyinfra, operations run strictly in definition order. The migration requires manually reordering operations: stop -> modify files -> restart. This is architecturally different and the `did_change` check happens at prepare time, before files are actually modified -- see two-phase-issues.md for the full implications.

---

## Summary

### Verbosity Comparison

| # | Directive | Salt Lines | pyinfra Lines | Delta | % Change |
|---|-----------|-----------|---------------|-------|----------|
| 1 | udev_rule onchanges | 5 | 6 | +1 | +20% |
| 2 | unit_override onchanges | 7 | 7 | 0 | 0% |
| 3 | user_service_file onchanges | 9 | 12 | +3 | +33% |
| 4 | user_unit_override onchanges | 11 | 13 | +2 | +18% |
| 5 | service_with_unit daemon-reload | 7 | 7 | 0 | 0% |
| 6 | service_with_unit running+watch | 10 | 16 | +6 | +60% |
| 7 | ensure_running watch | 10 | 9 | -1 | -10% |
| 8 | sysctl onchanges | 5 | 5 | 0 | 0% |
| 9 | network onchanges+onlyif | 8 | 9 | +1 | +13% |
| 10 | qmk udev onchanges | 5 | 5 | 0 | 0% |
| 11 | floorp multi-source onchanges | 8 | 12 | +4 | +50% |
| 12 | amnezia binary verification | 18 | 12 | -6 | -33% |
| 13 | resolved watch | 5 | 4 | -1 | -20% |
| 14 | adguardhome watch | 7 | 6 | -1 | -14% |
| 15 | transmission prereq+watch | 14 | 14 | 0 | 0% |
| | **Total** | **129** | **137** | **+8** | **+6%** |

### Key Findings

1. **Overall verbosity increase is modest** (+6%, 8 lines across 15 directives) -- but this understates the real cost.

2. **Hidden cost: upstream variable capture**. Every `did_change` check requires the caller to capture the `OperationMeta` return value from the upstream operation. This adds 1-2 lines per watched state at the *call site*, not counted in the table above. Across all 15 directives (watching ~25 total upstream states), this adds roughly 25-30 additional lines of variable assignments.

3. **Inverted dependency model**. In Salt, the downstream state declares what it watches (`watch: [file: foo]`). In pyinfra, the upstream operation must be explicitly captured (`foo = files.put(...)`) and the downstream must receive it (`if foo.did_change`). This makes refactoring harder -- moving a file operation between modules requires updating all downstream `did_change` consumers.

4. **`prereq` has no equivalent**. Transmission's stop-before-modify pattern (#15) requires manual operation reordering in pyinfra, which conflicts with the two-phase execution model.

5. **User-service onchanges is the most verbose** pattern (+33% for user_service_file, +18% for user_unit_override) due to the D-Bus environment boilerplate that must be repeated for every `systemctl --user` call.

6. **Loops reduce verbosity** in pyinfra. The amnezia verification (#12) and floorp extension reset (#11) are more compact as Python loops than repeated Salt states, partially offsetting the `did_change` overhead.

### Estimated Total Migration Cost for Watch/Onchanges

- **Direct line count**: +8 lines (129 -> 137)
- **Upstream capture overhead**: +25-30 lines (variable assignments at call sites)
- **Helper function definitions**: +20 lines (D-Bus env wrapper, is_failed checker)
- **Total estimated overhead**: ~55 additional lines of Python across the codebase
