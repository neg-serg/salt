# pyinfra Two-Phase Model Limitations

## The Problem

pyinfra uses a two-phase execution model:

1. **Prepare phase**: Python code runs top-to-bottom. Facts are gathered, `_if` guards are evaluated, and operations are queued. All conditionals (`if`, `_if` callables) are resolved here.
2. **Execute phase**: Queued operations run sequentially on the target host. No Python code runs between operations -- only the shell commands that were queued during prepare.

This means **facts gathered during prepare are stale by execute time**. If operation A installs a package and operation B checks whether that package exists (via a fact), B's check runs *before* A actually installs anything. The fact reflects the system state at prepare time, not after A runs.

Salt does not have this limitation. Each state evaluates its guards (`unless:`, `creates:`, `onlyif:`) at execution time, after all prerequisite states have completed. States can depend on the side effects of earlier states.

---

## Example 1: dns.sls -- Install Package, Then Run Its Command

### Salt (works correctly)

```yaml
# Step 1: Install unbound via pacman
install_unbound:
  cmd.run:
    - name: pacman -S --noconfirm --needed unbound
    - unless: rg -qx 'unbound' /tmp/.salt-pkg-list

# Step 2: Generate root key using unbound-anchor (ships with unbound)
unbound_root_key:
  cmd.run:
    - name: unbound-anchor -a /var/lib/unbound/root.key || true
    - creates: /var/lib/unbound/root.key
    - require:
      - cmd: install_unbound

# Step 3: Generate control certs using unbound-control-setup (ships with unbound)
unbound_control_certs:
  cmd.run:
    - name: unbound-control-setup
    - creates: /etc/unbound/unbound_server.pem
    - require:
      - cmd: install_unbound

# Step 4: Enable service (unbound.service ships with unbound package)
unbound_enabled:
  service.enabled:
    - name: unbound
    - require:
      - cmd: install_unbound
      - file: unbound_config
```

**Why it works in Salt**: Steps 2-4 have `require: [cmd: install_unbound]`. Salt evaluates `creates:` for steps 2-3 *after* step 1 completes. If unbound was just installed, `unbound-anchor` and `unbound-control-setup` are now in `$PATH` and can run.

### pyinfra (breaks on fresh install)

```python
# Step 1: Install unbound
pacman.packages(name="Install unbound", packages=["unbound"], present=True)

# Step 2: Generate root key
# BUG: _if runs at PREPARE time -- unbound-anchor doesn't exist yet!
server.shell(
    name="Generate unbound root key",
    commands=["unbound-anchor -a /var/lib/unbound/root.key || true"],
    _if=lambda: not host.get_fact(File, "/var/lib/unbound/root.key"),
)

# Step 3: Generate control certs
# BUG: Same issue -- unbound-control-setup not yet installed
server.shell(
    name="Generate unbound control certs",
    commands=["unbound-control-setup"],
    _if=lambda: not host.get_fact(File, "/etc/unbound/unbound_server.pem"),
)

# Step 4: Enable service
# BUG: systemd.service checks unit existence at prepare time
# unbound.service doesn't exist yet (package not installed)
systemd.service(name="Enable unbound", service="unbound", enabled=True)
```

**Why it breaks**: During prepare, pyinfra evaluates all `_if` guards and fact checks. On a fresh system where unbound is not installed:
- `host.get_fact(File, "/var/lib/unbound/root.key")` returns False (correct, file doesn't exist)
- But the `_if` guard is not the problem -- the **operation itself** (`unbound-anchor`) will be queued
- The real issue is `systemd.service()` which checks `systemctl` state during prepare -- if the unit file doesn't exist yet, pyinfra may skip or error

**The `_if` callable still runs at prepare time**. Even though it returns a callable (lambda), pyinfra evaluates that callable during the prepare phase, not at execution time. The `File` fact is gathered once and cached.

### Workaround

```python
# Option A: Unconditional shell commands with inline guards
pacman.packages(name="Install unbound", packages=["unbound"], present=True)

server.shell(
    name="Generate unbound root key + certs + enable",
    commands=["""
        test -f /var/lib/unbound/root.key || unbound-anchor -a /var/lib/unbound/root.key || true
        test -f /etc/unbound/unbound_server.pem || unbound-control-setup
        systemctl enable unbound
    """],
    _shell_executable="/bin/bash",
)
```

**Cost**: Loses granular operation tracking. All 3 steps are a single opaque shell command. No individual `did_change` tracking. Error in step 2 prevents step 3 from running.

```python
# Option B: Separate pyinfra deploy for post-install configuration
# deploy_1.py: package installation only
# deploy_2.py: configuration that depends on installed packages
# Requires two-pass invocation: pyinfra deploy_1.py && pyinfra deploy_2.py
```

**Cost**: Splits the deployment into multiple files with complex orchestration. Defeats the purpose of a single declarative config.

---

## Example 2: llama_embed.sls -- Install, Download Model, Deploy Unit, Start Service

### Salt (works correctly)

```yaml
# Step 1: Install llama.cpp-vulkan from AUR
install_llama_cpp_vulkan:
  cmd.run:
    - name: sudo -u neg paru -S --noconfirm --needed llama.cpp-vulkan
    - unless: rg -qx 'llama.cpp-vulkan' /tmp/.salt-pkg-list

# Step 2: Download 8GB model file
llama_embed_model:
  cmd.run:
    - name: curl -fsSL '...' -o '/mnt/one/llama-embed/models/model.gguf'
    - creates: /home/neg/.cache/salt-versions/llama_embed_model@Qwen3-Embedding-0.6B-Q8_0.gguf

# Step 3: Deploy systemd unit (templated with model path, port, etc.)
llama_embed_service:
  file.managed:
    - name: /etc/systemd/system/llama_embed.service
    - source: salt://units/llama-embed.service
    - template: jinja
    - context:
        model_file: Qwen3-Embedding-0.6B-Q8_0.gguf
        port: 11435
        # ...

# Step 4: Enable service (requires package + model + unit)
llama_embed_enabled:
  service.enabled:
    - name: llama_embed
    - onlyif: command -v llama-server
    - require:
      - cmd: llama_embed_model
      - cmd: install_llama_cpp_vulkan

# Step 5: Health check (requires service enabled)
llama_embed_start:
  cmd.run:
    - name: |
        systemctl daemon-reload
        systemctl restart llama_embed
        for i in $(seq 1 90); do
          curl -sf http://127.0.0.1:11435/health >/dev/null 2>&1 && exit 0
          sleep 1
        done
        exit 1
    - unless: curl -sf http://127.0.0.1:11435/health >/dev/null 2>&1
    - require:
      - service: llama_embed_enabled
```

**Why it works in Salt**: The `onlyif: command -v llama-server` in step 4 runs *after* step 1 installs the package. The `require` chain ensures steps run in order, and each step's guards evaluate at runtime.

### pyinfra (breaks on fresh install)

```python
# Step 1: AUR install
server.shell(
    name="AUR install llama.cpp-vulkan",
    commands=["sudo -u neg paru -S --noconfirm --needed llama.cpp-vulkan"],
    _if=lambda: not is_package_installed("llama.cpp-vulkan"),
)

# Step 4: Enable service
# BUG: onlyif='command -v llama-server' runs at PREPARE time
# llama-server doesn't exist yet (not installed)
systemd.service(
    name="Enable llama_embed",
    service="llama_embed",
    enabled=True,
    _if=lambda: shutil.which("llama-server") is not None,  # False at prepare time!
)

# Step 5: Health check
# BUG: unless check runs at prepare time -- service isn't running yet
server.shell(
    name="Start llama_embed with healthcheck",
    commands=["systemctl daemon-reload; systemctl restart llama_embed; ..."],
    _if=lambda: subprocess.run("curl -sf http://127.0.0.1:11435/health", shell=True).returncode != 0,
)
```

**Why it breaks**: At prepare time:
- `shutil.which("llama-server")` returns `None` because the package isn't installed yet. The `_if` guard evaluates to `False`, so step 4 is **skipped entirely** -- it won't even be queued for execution.
- The health check's `_if` correctly detects the service isn't running (returns True, meaning "should run"), but step 5 will fail because step 4 was skipped.

This is the most dangerous two-phase failure mode: **a guard that correctly evaluates to "skip" at prepare time, but would evaluate to "run" at execute time**. The operation is silently skipped with no error.

### Workaround

```python
# Option A: Remove all _if guards, use inline shell guards
server.shell(
    name="AUR install llama.cpp-vulkan",
    commands=["paru -Q llama.cpp-vulkan || sudo -u neg paru -S --noconfirm --needed llama.cpp-vulkan"],
)

server.shell(
    name="Enable + start llama_embed",
    commands=["""
        command -v llama-server || exit 0  # skip if not installed
        systemctl enable llama_embed
        systemctl daemon-reload
        systemctl restart llama_embed
        for i in $(seq 1 90); do
          curl -sf http://127.0.0.1:11435/health >/dev/null 2>&1 && exit 0
          sleep 1
        done
        exit 1
    """],
    _shell_executable="/bin/bash",
)
```

**Cost**: All guards move into shell scripts. pyinfra cannot report "skipped" vs "changed" vs "no change" -- every operation either runs its shell script or doesn't. Idempotency reporting is opaque.

```python
# Option B: Custom connector with runtime fact refresh
# pyinfra does not support this natively. Would require patching pyinfra's
# execution engine to re-gather facts between operations.
```

**Cost**: Requires forking pyinfra or writing a custom connector. Not a realistic option.

---

## Example 3: greetd.sls -- Install Package, Deploy Config, Enable Service

### Salt (works correctly)

```yaml
# Step 1: Install greetd
install_greetd:
  cmd.run:
    - name: pacman -S --noconfirm --needed greetd
    - unless: rg -qx 'greetd' /tmp/.salt-pkg-list

# Step 2: Deploy config (requires greetd installed for /etc/greetd/ to exist)
greetd_main_config:
  file.managed:
    - name: /etc/greetd/config.toml
    - contents: |
        [terminal]
        vt = 7
        [default_session]
        command = "/etc/greetd/greeter-wrapper"
        user = "neg"
    - require:
      - file: greetd_config_dir

# Step 3: Deploy greeter wrapper script (Jinja template with host variables)
greetd_greeter_wrapper:
  file.managed:
    - name: /etc/greetd/greeter-wrapper
    - source: salt://scripts/greetd-greeter-wrapper.sh.j2
    - template: jinja
    - context:
        greetd_scale: 2
        cursor_theme: Bibata-Modern-Classic
        # ...
    - mode: '0755'
    - require:
      - file: greetd_config_dir

# Step 4: Enable service (requires config to be in place)
greetd_enabled:
  service.enabled:
    - name: greetd
    - require:
      - file: greetd_main_config
```

**Why it works in Salt**: Step 2's `require: [file: greetd_config_dir]` ensures `/etc/greetd/` exists before writing configs. Step 4's `require: [file: greetd_main_config]` ensures config is deployed before enabling. All guards and facts are evaluated at runtime.

### pyinfra (subtly broken on fresh install)

```python
# Step 1: Install greetd
pacman.packages(name="Install greetd", packages=["greetd"], present=True)

# Step 2: Ensure config directory
files.directory(name="greetd config dir", path="/etc/greetd", mode="0755", user="root")

# Step 3: Deploy config
files.put(
    name="Deploy greetd config",
    dest="/etc/greetd/config.toml",
    src=StringIO(config_content),
    mode="0644",
)

# Step 4: Deploy greeter wrapper (Jinja template)
files.template(
    name="Deploy greeter wrapper",
    src="scripts/greetd-greeter-wrapper.sh.j2",
    dest="/etc/greetd/greeter-wrapper",
    mode="0755",
    greetd_scale=2, cursor_theme="Bibata-Modern-Classic",
)

# Step 5: Enable service
# SUBTLE BUG: systemd.service() gathers SystemdStatus fact at prepare time
# greetd.service unit file doesn't exist yet (package not installed)
# pyinfra may treat this as "unit not found" and skip or error
systemd.service(name="Enable greetd", service="greetd", enabled=True)
```

**Why it breaks (subtly)**: The `systemd.service()` operation gathers the `SystemdStatus` fact during prepare to determine current state. On a fresh system, the `greetd.service` unit doesn't exist (it's provided by the `greetd` package). pyinfra's fact-gathering may:
- Return an empty dict for the unit (causing pyinfra to attempt `systemctl enable greetd` anyway, which will succeed at execute time since the package is installed by then) -- this would **accidentally work**
- Raise an error during fact gathering if `systemctl show greetd` fails -- this would **break**

The behavior depends on pyinfra's `SystemdStatus` fact implementation. If it gracefully handles missing units, the operation works by accident. If it requires the unit to exist at fact-gathering time, it fails.

**The deeper issue**: This pattern (install package -> use files/services from package) is the **most common pattern in this codebase** -- used by unbound, adguardhome, ollama, greetd, avahi, samba, jellyfin, grafana, loki, promtail, and more. Every `simple_service()` and `service_with_unit()` macro invocation follows this pattern. If pyinfra's fact-gathering breaks on missing units, **the majority of service states fail on fresh install**.

### Workaround

```python
# Option A: Replace systemd.service() with server.shell() for all enable operations
server.shell(
    name="Enable greetd",
    commands=["systemctl enable greetd"],
    # No _if guard -- always run, systemctl enable is idempotent
)
```

**Cost**: Loses pyinfra's native systemd integration. Every `systemd.service()` call must be replaced with `server.shell()`, which doesn't report enable/disable state changes properly.

```python
# Option B: Two-pass deployment
# Pass 1: Install all packages
# Pass 2: Configure and enable services
# This guarantees all packages exist before any service configuration
```

**Cost**: Requires splitting every state file into "install" and "configure" phases. Doubles the number of deploy files and requires orchestration.

---

## Impact Summary

### Affected Patterns in This Codebase

| Pattern | Occurrences | Affected States | Severity |
|---------|------------|-----------------|----------|
| pacman install -> service.enabled | ~12 | dns, monitoring, services, greetd, steam | High |
| pacman install -> cmd.run (uses installed binary) | ~6 | dns (unbound-anchor), installers (qmk) | High |
| AUR install -> onlyif guard on installed binary | ~3 | llama_embed, kanata, ollama | Critical |
| Service healthcheck -> requires running service | ~5 | ollama, llama_embed, adguardhome, loki | Medium |
| file.managed -> onchanges -> daemon-reload | ~8 | All service_with_unit invocations | Low |

### Risk Matrix

| Two-Phase Issue | Fresh Install | Incremental Apply | Workaround Effort |
|----------------|---------------|-------------------|-------------------|
| Package install -> binary check | **BREAKS** | Works (binary exists) | Medium |
| Package install -> service enable | **MAY BREAK** | Works (unit exists) | Low |
| Package install -> onlyif guard | **SILENTLY SKIPS** | Works (binary exists) | High |
| Config change -> onchanges | Works (hash compare) | Works | N/A |

### Key Findings

1. **Fresh installs are the danger zone**. Incremental applies (where packages are already installed) work because facts reflect the correct state. The two-phase model only causes problems when operations depend on side effects of earlier operations *within the same deploy*.

2. **The `onlyif` / `_if` guard pattern is the most dangerous**. When a guard checks for an installed binary (`command -v`, `shutil.which()`) at prepare time, and the binary is installed during the same deploy, the guard **silently evaluates to "skip"** and the operation is never queued. There is no error -- the operation simply doesn't run.

3. **19+ states follow the install-then-configure pattern**. This is the dominant pattern in the codebase. Every `simple_service()`, `service_with_unit()`, and manual install-then-enable sequence is affected.

4. **The workarounds all degrade pyinfra's value proposition**:
   - Moving guards into shell scripts loses structured operation tracking
   - Two-pass deployment adds orchestration complexity
   - Removing `_if` guards makes every operation unconditional (slower incremental applies)

5. **Salt's runtime evaluation is a fundamental architectural advantage** for this codebase. The install-then-configure pattern is so pervasive that migrating to pyinfra would require either (a) accepting broken fresh installs, (b) restructuring all states into install/configure phases, or (c) abandoning pyinfra's fact/guard system in favor of inline shell guards.
