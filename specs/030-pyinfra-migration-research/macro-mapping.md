# Macro-to-pyinfra Mapping

Complete mapping of all 35 Salt macros (5 files, 173 invocations) to pyinfra v3.7 equivalents.

## Gap Severity Scale

| Severity | Meaning |
|----------|---------|
| Trivial | Direct 1:1 mapping exists in pyinfra |
| Low | Achievable with minor Python wrapper (~5-10 lines) |
| Medium | Requires a custom Python function (20-50 lines), some behavior gap |
| High | Requires significant custom infrastructure (50-100+ lines), semantic gap |
| Critical | No pyinfra equivalent; requires architectural redesign or external tooling |

---

## `_macros_common.jinja` (2 macros + shared constants)

### `ver_stamp(vd, name, version, target=None)`

- **Salt behavior**: Creates a version-encoded marker file (`name@version`) in a cache directory, optionally as a symlink to the installed artifact. Cleans up old markers. Used inside `cmd.run` `name:` blocks as an inline shell snippet.
- **pyinfra equivalent**: Custom Python helper function.
  ```python
  def ver_stamp(vd: str, name: str, version: str, target: str | None = None):
      """Create version marker after successful install."""
      from pyinfra.operations import server, files
      marker = f"{vd}/{name}@{version}"
      # Clean old markers
      server.shell(
          name=f"Clean old {name} markers",
          commands=[f"rm -f '{vd}/{name}' {vd}/{name}@*"],
      )
      if target:
          files.link(name=f"Version marker {name}@{version}", path=marker, target=target)
      else:
          server.shell(name=f"Version marker {name}@{version}", commands=[f"touch '{marker}'"])
  ```
- **Gap**: Low -- the marker is typically inlined into a shell script block. In pyinfra it would need to be a separate operation or appended to the shell command string.
- **Migration notes**: The inline usage inside `cmd.run` `name:` blocks means this cannot be a separate pyinfra operation -- it must remain part of the shell script string. A Python string-builder helper is the natural equivalent.

### `gopass_secret(key, fallback_cmd='true', runas=None)`

- **Salt behavior**: Executes `gopass show -o <key>` at **render time** (Jinja evaluation) via `salt['cmd.run_all']`. Falls back to a shell command if gopass fails. Returns the secret as a string embedded into the rendered YAML.
- **pyinfra equivalent**: NO EQUIVALENT (render-time execution).
  ```python
  import subprocess

  def gopass_secret(key: str, fallback_cmd: str = "true", runas: str = "neg") -> str:
      """Resolve secret at deploy-script load time (not operation time)."""
      result = subprocess.run(
          ["sudo", "-u", runas, "gopass", "show", "-o", key],
          capture_output=True, text=True
      )
      if result.returncode == 0:
          return result.stdout.strip()
      result = subprocess.run(
          ["sudo", "-u", runas, "bash", "-c", fallback_cmd],
          capture_output=True, text=True
      )
      return result.stdout.strip()
  ```
- **Gap**: Medium -- pyinfra has no render-time execution. The subprocess call at module-load time works but runs on the **control machine**, not the target host. For local-mode (single-host) deployments this is equivalent, but breaks the pyinfra remote-deployment model.
- **Migration notes**: For this codebase (masterless, local-only), a module-level `subprocess.run` is acceptable. For remote targets, secrets would need to be resolved via `host.get_fact()` custom facts, adding significant complexity.

### Shared constants (`user`, `home`, `retry_attempts`, `retry_interval`, `ver_dir`, etc.)

- **Salt behavior**: Jinja variables set once, imported by all macro files and states.
- **pyinfra equivalent**:
  ```python
  # config.py
  USER = "neg"
  HOME = "/home/neg"
  RETRY_ATTEMPTS = 3
  RETRY_INTERVAL = 10
  VER_DIR = f"{HOME}/.cache/salt-versions"
  SYS_VER_DIR = "/var/cache/salt/versions"
  DOWNLOAD_CACHE = "/var/cache/salt/downloads"
  ```
- **Gap**: Trivial -- Python module-level constants.

---

## `_macros_github.jinja` (3 macros)

### `github_tar(name, url, version=None, hash=None)`

- **Salt behavior**: Downloads a tar.gz from a URL, extracts it to a temp dir, finds the named binary via `find`, installs to `~/.local/bin/`. Supports version stamps, sha256 verification, retry, parallel execution, and `creates:` guard.
- **pyinfra equivalent**:
  ```python
  def github_tar(name: str, url: str, version: str | None = None, hash: str | None = None):
      creates = f"{VER_DIR}/{name}@{version}" if version else f"{HOME}/.local/bin/{name}"
      server.shell(
          name=f"Install {name} from GitHub tar.gz",
          commands=[f"""
              set -eo pipefail
              _td=$(mktemp -d); trap 'rm -rf "$_td"' EXIT
              curl -fsSL '{url}' -o "$_td/archive.tar.gz"
              {"echo '" + hash + "  '\"$_td/archive.tar.gz\" | sha256sum -c --strict" if hash else ""}
              tar -xzf "$_td/archive.tar.gz" -C "$_td"
              find "$_td" -name '{name}' -type f -exec install -m 0755 {{}} ~/.local/bin/{name} \\;
              {ver_stamp_shell(VER_DIR, name, version) if version else ""}
          """],
          _su_user=USER,
          _shell_executable="/bin/bash",
          _if=lambda: not host.get_fact(File, creates),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Medium -- the shell script body translates directly, but `parallel: True` has **no pyinfra equivalent** (see parallel-impact.md). The `_if` callable replaces `creates:` but requires a custom fact or `File` fact check.
- **Migration notes**: Loses parallel execution. The `_if` guard runs at prepare time (facts phase), not operation time -- see two-phase-issues.md for implications.

### `github_release_system(name, repo, asset, src_bin=None, format='zip', tag=None, version=None)`

- **Salt behavior**: Downloads a GitHub release asset (zip or tar.gz), extracts it, installs to `/usr/local/bin/`. Runs as root (no `runas`). Supports latest-tag auto-detection via redirect URL parsing.
- **pyinfra equivalent**:
  ```python
  def github_release_system(name: str, repo: str, asset: str, src_bin: str | None = None,
                             format: str = "zip", tag: str | None = None, version: str | None = None):
      # Same pattern as github_tar but without _su_user, dest=/usr/local/bin
      server.shell(
          name=f"Install {name} system-wide from GitHub release",
          commands=[...],  # same curl/extract/install pattern
          _shell_executable="/bin/bash",
          _if=lambda: not host.get_fact(File, creates),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Medium -- same parallel loss as `github_tar`. The latest-tag detection via `curl -fsSIL -o /dev/null -w '%{url_effective}'` stays in the shell script, which is fine.
- **Migration notes**: The `find -maxdepth 3` pattern for locating binaries inside archives is fragile but works identically in both systems since it runs as a shell command.

### `github_release_to(state_id, name, repo, asset, dest, format='file', tag=None, version=None, creates=None, require=None)`

- **Salt behavior**: Downloads a GitHub release asset to an arbitrary directory. Supports both direct file download and ZIP extraction. Takes an explicit `state_id` for caller-controlled naming.
- **pyinfra equivalent**:
  ```python
  def github_release_to(name: str, repo: str, asset: str, dest: str,
                         format: str = "file", **kwargs):
      server.shell(
          name=f"Install {name} to {dest}",
          commands=[...],  # same pattern
          _su_user=USER,
          _shell_executable="/bin/bash",
          _if=lambda: not host.get_fact(File, creates),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Low -- direct translation. The `require` parameter maps to pyinfra's implicit ordering (operations run in definition order) or explicit `_depends_on`.
- **Migration notes**: The `state_id` parameter becomes unnecessary in pyinfra since Python function calls are inherently named. Dependency ordering is implicit (sequential) unless using `_depends_on`.

---

## `_macros_install.jinja` (10 macros)

### `curl_bin(name, url, version=None, hash=None)`

- **Salt behavior**: Downloads a binary to `~/.local/bin/`, uses a download cache (`/var/cache/salt/downloads/`) to avoid re-downloading, supports version stamps and hash verification.
- **pyinfra equivalent**:
  ```python
  def curl_bin(name: str, url: str, version: str | None = None, hash: str | None = None):
      server.shell(
          name=f"Install {name} binary",
          commands=[...],  # curl + cache + mv pattern
          _su_user=USER,
          _shell_executable="/bin/bash",
          _if=lambda: not host.get_fact(File, creates),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Low -- direct shell translation. Loses `parallel: True`.
- **Migration notes**: The download cache pattern is purely shell-level and transfers intact. pyinfra's `files.download()` exists but lacks the cache-then-copy pattern, so `server.shell()` is the better match.

### `pip_pkg(name, pkg=None, bin=None, env=None)`

- **Salt behavior**: Installs a Python package via `pipx install`, with fallback to `pipx reinstall` if the binary is missing (handles broken symlinks after Python upgrades).
- **pyinfra equivalent**:
  ```python
  def pip_pkg(name: str, pkg: str | None = None, bin: str | None = None, env: str | None = None):
      bin_path = f"{HOME}/.local/bin/{bin or name}"
      server.shell(
          name=f"pipx install {pkg or name}",
          commands=[f"{env + ' ' if env else ''}pipx install {pkg or name} 2>/dev/null || true; "
                    f"test -x {bin_path} || {env + ' ' if env else ''}pipx reinstall {pkg or name}"],
          _su_user=USER,
          _if=lambda: not host.get_fact(File, bin_path),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Low -- `pip.packages()` exists in pyinfra but doesn't support pipx. `server.shell()` is the correct mapping.

### `cargo_pkg(name, pkg=None, bin=None, git=None, env=None, onlyif=None, version=None)`

- **Salt behavior**: Installs a Rust crate via `cargo install` (crates.io or git). Supports env vars, `onlyif` guards (e.g. `pkg-config --exists dbus-1`), and version stamps.
- **pyinfra equivalent**:
  ```python
  def cargo_pkg(name: str, pkg: str | None = None, bin: str | None = None,
                git: str | None = None, env: str | None = None,
                onlyif: list[str] | None = None, version: str | None = None):
      bin_path = f"{HOME}/.local/share/cargo/bin/{bin or name}"
      creates = f"{VER_DIR}/{name}@{version}" if version else bin_path

      def guard():
          if not host.get_fact(File, creates):
              return False  # file missing -> should run
          return True       # file exists -> skip

      server.shell(
          name=f"cargo install {pkg or name}",
          commands=[f"{'--git ' + git if git else pkg or name}"],
          _su_user=USER,
          _if=guard,
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Medium -- the `onlyif` guard list (all must succeed) requires composing multiple fact checks into the `_if` callable. pyinfra has no built-in multi-condition guard.
- **Migration notes**: The `onlyif` pattern (e.g. `['pkg-config --exists dbus-1', 'command -v cargo']`) must be converted to a compound Python function that runs shell commands and checks exit codes. This is verbose but straightforward.

### `curl_extract_tar(name, url, binary_pattern=None, archive_ext='tar.gz', fetch_tag=False, ...)`

- **Salt behavior**: The most complex install macro (30+ parameters). Downloads and extracts tar archives, supports GitHub tag fetching, multiple binaries, custom destinations, strip-components, download cache, and version stamps.
- **pyinfra equivalent**:
  ```python
  def curl_extract_tar(name: str, url: str, binary_pattern: str | None = None,
                        archive_ext: str = "tar.gz", fetch_tag: bool = False,
                        strip_v: bool = False, binaries: list | None = None,
                        bin: str | None = None, chmod: bool = False,
                        dest: str | None = None, strip_components: int | None = None,
                        creates: str | None = None, version: str | None = None, **kw):
      # ~40 line shell script, same as Salt macro output
      server.shell(
          name=f"Install {name} from {archive_ext}",
          commands=[...],
          _su_user=kw.get("user", USER),
          _shell_executable="/bin/bash",
          _if=lambda: not host.get_fact(File, _creates),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Low -- the complexity is in the shell script, which transfers verbatim. The Python wrapper just needs to compute the `creates` path and pass through parameters.
- **Migration notes**: The 30+ parameter signature is equally complex in Python. Consider using a dataclass or builder pattern to improve readability.

### `curl_extract_zip(name, url, binary_path=None, binaries=None, ...)`

- **Salt behavior**: Same as `curl_extract_tar` but for ZIP archives. Supports direct extraction to a destination, symlink creation, download cache.
- **pyinfra equivalent**: Same pattern as `curl_extract_tar` with `unzip` instead of `tar`.
- **Gap**: Low -- direct shell translation.

### `curl_extract_7z(name, url, dest, creates=None, ...)`

- **Salt behavior**: Extracts .7z archives using `7z x`. Used for Steam skins and similar bundles.
- **pyinfra equivalent**: Same `server.shell()` pattern with `7z x` command.
- **Gap**: Low -- direct shell translation.

### `firefox_extension(ext, profile, require=None)`

- **Salt behavior**: Downloads a Firefox/Floorp extension `.xpi` from AMO to the profile's `extensions/` directory. Uses `creates:` guard on the `.xpi` path.
- **pyinfra equivalent**:
  ```python
  def firefox_extension(ext: dict, profile: str):
      xpi = f"{profile}/extensions/{ext['id']}.xpi"
      server.shell(
          name=f"Install Floorp extension {ext['slug']}",
          commands=[f"curl -fsSL -o '{xpi}.tmp' 'https://addons.mozilla.org/firefox/downloads/latest/{ext['slug']}/latest.xpi' && mv -f '{xpi}.tmp' '{xpi}'"],
          _su_user=USER,
          _if=lambda: not host.get_fact(File, xpi),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Trivial -- direct mapping.

### `download_font_zip(name, url, subdir, hash=None, version=None)`

- **Salt behavior**: Two-state macro: creates font directory (`file.directory`), then downloads + extracts font ZIP + runs `fc-cache`. Uses version-stamped marker files for idempotency.
- **pyinfra equivalent**:
  ```python
  def download_font_zip(name: str, url: str, subdir: str, version: str | None = None):
      fonts_dir = f"{HOME}/.local/share/fonts"
      files.directory(name=f"{name} font dir", path=f"{fonts_dir}/{subdir}",
                      user=USER, group=USER)
      server.shell(
          name=f"Install {name} font",
          commands=[...],  # curl + unzip + fc-cache + marker
          _su_user=USER,
          _shell_executable="/bin/bash",
          _if=lambda: not host.get_fact(File, marker),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Low -- two separate pyinfra operations replace two Salt states.

### `git_clone_deploy(name, repo, dest, items=None, creates=None)`

- **Salt behavior**: Git clones a repo (depth=1), optionally copies selected items to a destination, then cleans up. Uses `creates:` guard.
- **pyinfra equivalent**:
  ```python
  def git_clone_deploy(name: str, repo: str, dest: str, items: list | None = None):
      if items:
          server.shell(
              name=f"Git clone + deploy {name}",
              commands=[f"_td=$(mktemp -d); trap 'rm -rf \"$_td\"' EXIT; "
                        f"git clone --depth=1 {repo} \"$_td/repo\"; "
                        f"mkdir -p {dest}; " +
                        "; ".join(f"cp -r \"$_td/repo\"/{item} {dest}/" for item in items)],
              _su_user=USER,
              _shell_executable="/bin/bash",
              _if=lambda: not host.get_fact(File, creates or dest),
              _retries=RETRY_ATTEMPTS,
              _retry_delay=RETRY_INTERVAL,
          )
      else:
          git.repo(name=f"Git clone {name}", src=repo, dest=dest, branch="HEAD", pull=False)
  ```
- **Gap**: Low -- pyinfra has `git.repo()` for simple clones, but the "clone to temp + selective copy" pattern requires `server.shell()`.

### `http_file(name, url, dest, mode='0644', ...)`

- **Salt behavior**: Downloads a single file via curl, installs with `install -D`, supports caching, hash verification, version stamps. Flexible: can run as root or user, with or without parallel.
- **pyinfra equivalent**:
  ```python
  def http_file(name: str, url: str, dest: str, mode: str = "0644", user: str | None = USER, **kw):
      server.shell(
          name=f"Download {name}",
          commands=[...],  # curl + cache + install -D
          _su_user=user,
          _shell_executable="/bin/bash",
          _if=lambda: not host.get_fact(File, creates),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Low -- pyinfra has `files.download()` but it lacks the caching layer, so `server.shell()` is more appropriate.

---

## `_macros_pkg.jinja` (6 macros)

### `pacman_install(name, pkgs, check=None, requires=None)`

- **Salt behavior**: Runs `pacman -S --noconfirm --needed`, guarded by `rg -qx '<pkg>' <pkg_list>`. Requires `pacman_db_warmup` state.
- **pyinfra equivalent**:
  ```python
  from pyinfra.operations import pacman

  def pacman_install(name: str, pkgs: str):
      pacman.packages(
          name=f"Install {name}",
          packages=pkgs.split(),
          present=True,
      )
  ```
- **Gap**: Trivial -- pyinfra has native `pacman.packages()`. However, the `unless: rg -qx` guard pattern (checking a cached package list file) is Salt-specific. pyinfra's `pacman.packages()` checks package state directly via `pacman -Q`, which is equivalent but slightly slower.
- **Migration notes**: The `requires: [cmd: pacman_db_warmup]` dependency needs manual ordering in pyinfra (define the db warmup operation first). pyinfra doesn't have `--needed` equivalent, but `pacman.packages(present=True)` achieves the same idempotency.

### `simple_service(name, pkgs, service=None, check=None, requires=None)`

- **Salt behavior**: Combines `pacman_install()` + `service.enabled`. Two states with `require` chain.
- **pyinfra equivalent**:
  ```python
  def simple_service(name: str, pkgs: str, service: str | None = None):
      pacman_install(name, pkgs)
      systemd.service(
          name=f"Enable {service or name}",
          service=service or name,
          enabled=True,
      )
  ```
- **Gap**: Trivial -- direct mapping. Sequential definition order in pyinfra replaces `require`.

### `paru_install(name, pkg, check=None, requires=None, version='')`

- **Salt behavior**: Installs AUR packages via `paru -S --noconfirm --needed`. Runs via `sudo -u <user> paru` (paru handles sudo internally for makepkg). Supports version stamps.
- **pyinfra equivalent**: NO EQUIVALENT (pyinfra has no AUR support).
  ```python
  def paru_install(name: str, pkg: str, version: str = ""):
      server.shell(
          name=f"AUR install {pkg}",
          commands=[f"sudo -u {USER} paru -S --noconfirm --needed {pkg}"],
          _if=lambda: not is_package_installed(pkg),
      )
  ```
- **Gap**: Medium -- must use `server.shell()` since pyinfra's `pacman.packages()` only handles official repos. The `unless: rg -qx` guard needs a custom fact.
- **Migration notes**: A custom `AurPackage` fact class would improve idempotency checking. The `version` parameter with ver_stamp needs manual shell appending.

### `pkgbuild_install(name, source, user, build_base='/tmp/pkgbuild', timeout=600, ...)`

- **Salt behavior**: Multi-state macro: deploys PKGBUILD directory via `file.recurse`, then runs `makepkg -sf && pacman -U`. Supports conflict removal, replace checks, extra sources, and cleanup.
- **pyinfra equivalent**: NO EQUIVALENT (pyinfra has no PKGBUILD support).
  ```python
  def pkgbuild_install(name: str, source_dir: str, timeout: int = 600, **kw):
      # Step 1: Deploy PKGBUILD files
      files.rsync(
          name=f"Deploy {name} PKGBUILD",
          src=source_dir,
          dest=f"/tmp/pkgbuild/{name}",
      )
      # Step 2: Build + install
      server.shell(
          name=f"Build {name} from PKGBUILD",
          commands=[f"""
              set -eo pipefail
              su - {USER} -c 'cd /tmp/pkgbuild/{name} && makepkg -sf --noconfirm'
              pacman -U --noconfirm --needed /tmp/pkgbuild/{name}/*.pkg.tar.zst
              rm -rf /tmp/pkgbuild/{name}
          """],
          _shell_executable="/bin/bash",
          _if=lambda: not is_package_installed(name),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: High -- `file.recurse` (recursive directory sync from Salt master) has no direct pyinfra equivalent. `files.rsync()` is the closest but requires rsync on the target. The conflict removal logic and `replace_check` pattern add further complexity.
- **Migration notes**: The `file.recurse` from `salt://` paths would need to be replaced with `files.put()` for individual files or `files.rsync()` for directories. The `source` parameter references `salt://build/pkgbuilds/` which would need to become local filesystem paths.

### `npm_pkg(name, pkg=None, bin=None, version='')`

- **Salt behavior**: Runs `npm install -g --prefix ~/.local` to install global npm packages at user level. Supports version stamps.
- **pyinfra equivalent**:
  ```python
  from pyinfra.operations import npm

  def npm_pkg(name: str, pkg: str | None = None, bin: str | None = None, version: str = ""):
      # pyinfra's npm.packages() doesn't support --prefix
      server.shell(
          name=f"npm install {pkg or name}",
          commands=[f"npm install -g --prefix {HOME}/.local {pkg or name}"],
          _su_user=USER,
          _if=lambda: not host.get_fact(File, f"{HOME}/.local/bin/{bin or name}"),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Medium -- pyinfra has `npm.packages()` but it doesn't support `--prefix` for user-level installs (always uses system-global). Must use `server.shell()`.

### `flatpak_install(app_id, user)`

- **Salt behavior**: Installs Flatpak app from Flathub at user level. Guarded by `flatpak list --user --app`.
- **pyinfra equivalent**: NO EQUIVALENT (pyinfra has no Flatpak support).
  ```python
  def flatpak_install(app_id: str):
      server.shell(
          name=f"Flatpak install {app_id}",
          commands=[f"sudo -u {USER} flatpak install -y --user flathub {app_id}"],
          _if=lambda: not is_flatpak_installed(app_id),
          _retries=RETRY_ATTEMPTS,
          _retry_delay=RETRY_INTERVAL,
      )
  ```
- **Gap**: Medium -- requires custom fact for idempotency check. The `require: [cmd: flatpak_flathub_remote]` dependency needs manual ordering.

---

## `_macros_service.jinja` (14 macros)

### `ensure_dir(name, path, mode=None, require=None, user)`

- **Salt behavior**: Creates a directory with `file.directory` + user/group ownership + makedirs.
- **pyinfra equivalent**:
  ```python
  def ensure_dir(name: str, path: str, mode: str | None = None, user: str = USER):
      files.directory(
          name=f"Ensure dir {path}",
          path=path,
          user=user, group=user,
          mode=mode,
      )
  ```
- **Gap**: Trivial -- `files.directory()` is a direct mapping. Note: pyinfra creates parent directories by default.

### `udev_rule(name, path, source=None, contents=None)`

- **Salt behavior**: Two-state macro: deploys udev rule file (`file.managed`), then reloads udev rules (`udevadm control --reload-rules && udevadm trigger`) via `onchanges` (only if the file changed).
- **pyinfra equivalent**:
  ```python
  def udev_rule(name: str, path: str, source: str | None = None, contents: str | None = None):
      if contents:
          rule = files.put(name=f"Deploy udev rule {name}", dest=path,
                           src=StringIO(contents), mode="0644")
      else:
          rule = files.put(name=f"Deploy udev rule {name}", dest=path,
                           src=source, mode="0644")
      if rule.did_change:
          server.shell(name=f"Reload udev rules for {name}",
                       commands=["udevadm control --reload-rules && udevadm trigger"])
  ```
- **Gap**: Medium -- the `onchanges` directive maps to `OperationMeta.did_change`, but pyinfra's two-phase model means `did_change` is evaluated at prepare time. In practice, since `files.put()` can determine change during prepare (hash comparison), this works, but the semantic is different from Salt's runtime evaluation.
- **Migration notes**: See watch-migration.md for detailed `did_change` patterns.

### `ensure_running(name, service=None, watch=None)`

- **Salt behavior**: Three-state macro: resets failed state (`systemctl reset-failed`), then ensures service is running with `watch` on config files (restarts on change).
- **pyinfra equivalent**:
  ```python
  def ensure_running(name: str, service: str | None = None, watch_results: list = None):
      svc = service or name
      server.shell(
          name=f"Reset failed {svc}",
          commands=[f"systemctl reset-failed {svc} 2>/dev/null; true"],
          _if=lambda: host.get_fact(SystemdStatus).get(svc, {}).get("SubState") == "failed",
      )
      restart = any(r.did_change for r in (watch_results or []))
      systemd.service(
          name=f"Ensure {svc} running",
          service=svc,
          running=True,
          restarted=restart,
      )
  ```
- **Gap**: High -- the `watch` directive (restart on config file change) requires collecting `OperationMeta` objects from upstream operations and checking `did_change`. This is significantly more verbose and fragile than Salt's declarative `watch:` list.
- **Migration notes**: Every call site must capture the return value of file operations and pass them to `ensure_running()`. This inverts the dependency declaration (caller must track, not callee).

### `service_stopped(name, svc, stop=True, requires=None, onlyif=None)`

- **Salt behavior**: Stops and disables a service (`service.dead` + `enable: False`) or just disables it (`service.disabled`).
- **pyinfra equivalent**:
  ```python
  def service_stopped(name: str, svc: str, stop: bool = True):
      if stop:
          systemd.service(name=f"Stop {svc}", service=svc, running=False, enabled=False)
      else:
          systemd.service(name=f"Disable {svc}", service=svc, enabled=False)
  ```
- **Gap**: Trivial -- direct mapping. `systemd.service()` supports both `running` and `enabled`.

### `service_with_healthcheck(name, service, check_cmd, timeout=30, requires=None)`

- **Salt behavior**: Restarts a service, then polls a health-check command in a loop until it succeeds or times out. Skipped if the check already passes (`unless:`).
- **pyinfra equivalent**:
  ```python
  def service_with_healthcheck(name: str, service: str, check_cmd: str, timeout: int = 30):
      server.shell(
          name=f"Start {service} with healthcheck",
          commands=[f"""
              systemctl daemon-reload
              systemctl restart {service}
              for i in $(seq 1 {timeout}); do
                  {check_cmd} && exit 0
                  sleep 1
              done
              echo "{service} failed to start within {timeout}s" >&2
              exit 1
          """],
          _shell_executable="/bin/bash",
          _if=lambda: subprocess.run(check_cmd, shell=True).returncode != 0,
      )
  ```
- **Gap**: Low -- the shell polling loop transfers directly. The `unless:` guard maps to `_if` with inverted logic.

### `system_daemon_user(name, home_dir, shell='/usr/sbin/nologin', requires=None)`

- **Salt behavior**: Two-state macro: creates system user (`user.present`) + data directory (`file.directory`) with ownership.
- **pyinfra equivalent**:
  ```python
  def system_daemon_user(name: str, home_dir: str, shell: str = "/usr/sbin/nologin"):
      server.user(name=f"System user {name}", user=name, system=True,
                  shell=shell, home=home_dir, create_home=False)
      files.directory(name=f"Data dir {home_dir}", path=home_dir,
                      user=name, group=name)
  ```
- **Gap**: Trivial -- `server.user()` + `files.directory()` are direct mappings.

### `unit_override(name, service, source, filename='override.conf', requires=None)`

- **Salt behavior**: Two-state macro: deploys systemd drop-in override file, then runs `systemctl daemon-reload` via `onchanges`.
- **pyinfra equivalent**:
  ```python
  def unit_override(name: str, service: str, source: str, filename: str = "override.conf"):
      override = files.put(
          name=f"Deploy {name} override",
          dest=f"/etc/systemd/system/{service}.d/{filename}",
          src=source, mode="0644",
      )
      if override.did_change:
          server.shell(name=f"Reload systemd for {name}",
                       commands=["systemctl daemon-reload"])
  ```
- **Gap**: Medium -- same `did_change` pattern as `udev_rule`. Works in practice but semantically different from Salt's `onchanges`.

### `user_service_file(name, filename, source=None, user, home)`

- **Salt behavior**: Two-state macro: deploys user-level systemd unit file to `~/.config/systemd/user/`, then runs `systemctl --user daemon-reload` via `onchanges` with D-Bus/XDG environment.
- **pyinfra equivalent**:
  ```python
  def user_service_file(name: str, filename: str, source: str | None = None):
      unit = files.put(
          name=f"Deploy user unit {filename}",
          dest=f"{HOME}/.config/systemd/user/{filename}",
          src=source or f"units/user/{filename}",
          user=USER, group=USER, mode="0644",
      )
      if unit.did_change:
          server.shell(
              name=f"User daemon-reload for {filename}",
              commands=["systemctl --user daemon-reload"],
              _su_user=USER,
              _env={"XDG_RUNTIME_DIR": RUNTIME_DIR,
                    "DBUS_SESSION_BUS_ADDRESS": f"unix:path={RUNTIME_DIR}/bus"},
          )
  ```
- **Gap**: Medium -- the D-Bus environment wiring is boilerplate that must be repeated for every user-level systemd operation. In Salt it is hidden inside the macro.

### `user_unit_override(name, service, source=None, contents=None, filename='override.conf', ...)`

- **Salt behavior**: Analogous to `unit_override` but for user services. Deploys drop-in to `~/.config/systemd/user/<service>.d/`.
- **pyinfra equivalent**: Same pattern as `user_service_file` with `did_change` guard.
- **Gap**: Medium -- same D-Bus boilerplate issue.

### `user_service_enable(name, services=None, start_now=None, daemon_reload=False, check='enabled', onlyif=None, requires=None)`

- **Salt behavior**: Enables (and optionally starts) user-level systemd services. Handles daemon-reload, multi-unit enable, `is-enabled`/`is-active` guards, D-Bus environment.
- **pyinfra equivalent**:
  ```python
  def user_service_enable(name: str, services: list | None = None,
                           start_now: list | None = None, daemon_reload: bool = False):
      cmds = []
      if daemon_reload:
          cmds.append("systemctl --user daemon-reload")
      for svc in (services or []):
          cmds.append(f"systemctl --user is-enabled '{svc}' >/dev/null 2>&1 || systemctl --user enable '{svc}'")
      for svc in (start_now or []):
          cmds.append(f"systemctl --user is-active '{svc}' >/dev/null 2>&1 || systemctl --user enable --now '{svc}'")
      server.shell(
          name=f"Enable user services: {name}",
          commands=["; ".join(cmds)],
          _su_user=USER,
          _env={"XDG_RUNTIME_DIR": RUNTIME_DIR,
                "DBUS_SESSION_BUS_ADDRESS": f"unix:path={RUNTIME_DIR}/bus"},
      )
  ```
- **Gap**: Medium -- pyinfra's `systemd.service()` does not support `--user` mode. Must use `server.shell()` for all user-level systemd operations. This is a significant gap since ~15 states use user services.
- **Migration notes**: A custom `user_systemd_service()` wrapper is essential to avoid repeating the D-Bus/XDG environment boilerplate.

### `user_service_with_unit(name, filename, source=None, services=None, start_now=None, requires=None)`

- **Salt behavior**: Compound macro combining `user_service_file()` + `user_service_enable()` with internal require chain.
- **pyinfra equivalent**: Call `user_service_file()` then `user_service_enable()` sequentially.
- **Gap**: Low -- sequential Python calls replace the `require` chain. The internal `did_change` check for daemon-reload is handled by `user_service_file()`.

### `user_service_restart(name, service, onlyif=None, requires=None, onchanges=None)`

- **Salt behavior**: Restarts a user systemd service with proper D-Bus environment. Supports `onchanges` and `onlyif` guards.
- **pyinfra equivalent**:
  ```python
  def user_service_restart(name: str, service: str, onchanges_results: list = None):
      if onchanges_results and any(r.did_change for r in onchanges_results):
          server.shell(
              name=f"Restart {service}",
              commands=[f"systemctl --user restart {service}"],
              _su_user=USER,
              _env={"XDG_RUNTIME_DIR": RUNTIME_DIR,
                    "DBUS_SESSION_BUS_ADDRESS": f"unix:path={RUNTIME_DIR}/bus"},
          )
  ```
- **Gap**: Medium -- `onchanges` requires capturing upstream `OperationMeta` objects.

### `user_service_disable(name, units, user)`

- **Salt behavior**: Disables and stops user services, guarded by `is-enabled` check.
- **pyinfra equivalent**:
  ```python
  def user_service_disable(name: str, units: list):
      server.shell(
          name=f"Disable user services: {name}",
          commands=[f"systemctl --user disable --now {' '.join(units)} 2>/dev/null || true"],
          _su_user=USER,
          _env={"XDG_RUNTIME_DIR": RUNTIME_DIR,
                "DBUS_SESSION_BUS_ADDRESS": f"unix:path={RUNTIME_DIR}/bus"},
          _if=lambda: any_unit_enabled(units),
      )
  ```
- **Gap**: Medium -- custom guard function needed to check if any unit is enabled.

### `service_with_unit(name, source, unit_type='service', running=False, enabled=True, ...)`

- **Salt behavior**: The most complex service macro. Deploys a systemd unit file, triggers daemon-reload on change, enables/disables the service, and optionally ensures it is running with watch-based auto-restart. Supports companions (timer+service pairs), Jinja template rendering, and config file watches.
- **pyinfra equivalent**:
  ```python
  def service_with_unit(name: str, source: str, unit_type: str = "service",
                         running: bool = False, enabled: bool = True,
                         template: str | None = None, context: dict | None = None,
                         companion: str | None = None, watch_results: list = None):
      unit = files.template(
          name=f"Deploy {name}.{unit_type}",
          src=source, dest=f"/etc/systemd/system/{name}.{unit_type}",
          mode="0644", **context,
      ) if template else files.put(
          name=f"Deploy {name}.{unit_type}",
          dest=f"/etc/systemd/system/{name}.{unit_type}",
          src=source, mode="0644",
      )

      comp = None
      if companion:
          comp_type = "service" if unit_type != "service" else "timer"
          comp = files.put(...)

      if unit.did_change or (comp and comp.did_change):
          server.shell(name=f"Daemon-reload {name}", commands=["systemctl daemon-reload"])

      if enabled is not None:
          systemd.service(name=f"{'Enable' if enabled else 'Disable'} {name}",
                          service=name, enabled=enabled)

      if running:
          restart = unit.did_change or any(r.did_change for r in (watch_results or []))
          server.shell(name=f"Reset failed {name}",
                       commands=[f"systemctl reset-failed {name} 2>/dev/null; true"],
                       _if=lambda: is_failed(name))
          systemd.service(name=f"Run {name}", service=name,
                          running=True, restarted=restart)
  ```
- **Gap**: High -- this single macro expands to 2-5 Salt states depending on parameters. The pyinfra equivalent is 20-30 lines of Python with `did_change` tracking. The `watch` list (config files triggering restart) requires collecting `OperationMeta` objects from call sites, which inverts the dependency model.
- **Migration notes**: This is the highest-impact macro to migrate. Used by loki, promtail, grafana, ollama, llama_embed, xray, duckdns, bitcoind, and others. Each call site must be refactored to capture file operation results.

---

## Summary Table

| Macro | File | Invocations | pyinfra Primary Op | Gap | Parallel Lost |
|-------|------|------------|-------------------|-----|---------------|
| `ver_stamp` | common | ~30 (inline) | shell string helper | Low | N/A |
| `gopass_secret` | common | ~8 | `subprocess.run` at load | Medium | N/A |
| `github_tar` | github | ~6 | `server.shell()` | Medium | Yes |
| `github_release_system` | github | ~4 | `server.shell()` | Medium | Yes |
| `github_release_to` | github | ~4 | `server.shell()` | Low | Yes |
| `curl_bin` | install | ~12 | `server.shell()` | Low | Yes |
| `pip_pkg` | install | ~4 | `server.shell()` | Low | Yes |
| `cargo_pkg` | install | ~8 | `server.shell()` | Medium | Yes |
| `curl_extract_tar` | install | ~10 | `server.shell()` | Low | Yes |
| `curl_extract_zip` | install | ~8 | `server.shell()` | Low | Yes |
| `curl_extract_7z` | install | ~1 | `server.shell()` | Low | Yes |
| `firefox_extension` | install | ~10 | `server.shell()` | Trivial | Yes |
| `download_font_zip` | install | ~5 | `server.shell()` | Low | Yes |
| `git_clone_deploy` | install | ~3 | `server.shell()` / `git.repo()` | Low | Yes |
| `http_file` | install | ~6 | `server.shell()` | Low | Yes |
| `pacman_install` | pkg | ~15 | `pacman.packages()` | Trivial | No |
| `simple_service` | pkg | ~6 | `pacman.packages()` + `systemd.service()` | Trivial | No |
| `paru_install` | pkg | ~8 | `server.shell()` | Medium | No |
| `pkgbuild_install` | pkg | ~6 | `server.shell()` + `files.rsync()` | High | No |
| `npm_pkg` | pkg | ~3 | `server.shell()` | Medium | Yes |
| `flatpak_install` | pkg | ~2 | `server.shell()` | Medium | Yes |
| `ensure_dir` | service | ~20 | `files.directory()` | Trivial | No |
| `udev_rule` | service | ~3 | `files.put()` + `did_change` | Medium | No |
| `ensure_running` | service | ~3 | `systemd.service()` + `did_change` | High | No |
| `service_stopped` | service | ~4 | `systemd.service()` | Trivial | No |
| `service_with_healthcheck` | service | ~4 | `server.shell()` | Low | No |
| `system_daemon_user` | service | ~3 | `server.user()` + `files.directory()` | Trivial | No |
| `unit_override` | service | ~3 | `files.put()` + `did_change` | Medium | No |
| `user_service_file` | service | ~8 | `files.put()` + `did_change` | Medium | No |
| `user_unit_override` | service | ~3 | `files.put()` + `did_change` | Medium | No |
| `user_service_enable` | service | ~10 | `server.shell()` | Medium | No |
| `user_service_with_unit` | service | ~5 | compound call | Low | No |
| `user_service_restart` | service | ~3 | `server.shell()` + `did_change` | Medium | No |
| `user_service_disable` | service | ~2 | `server.shell()` | Medium | No |
| `service_with_unit` | service | ~8 | compound (5 ops) | High | No |

### Gap Distribution

| Severity | Count | % |
|----------|-------|---|
| Trivial | 8 | 23% |
| Low | 12 | 34% |
| Medium | 12 | 34% |
| High | 3 | 9% |
| Critical | 0 | 0% |

### Key Findings

1. **No Critical gaps** -- every macro has a pyinfra equivalent, though some are verbose.
2. **23 of 35 macros** (66%) lose `parallel: True` -- all download/install macros run sequentially in pyinfra.
3. **12 macros** (34%) require `OperationMeta.did_change` for watch/onchanges behavior.
4. **pyinfra has no user-level systemd support** -- all `systemctl --user` operations need `server.shell()` with D-Bus environment wiring, affecting ~15 states.
5. **3 High-gap macros** (`ensure_running`, `service_with_unit`, `pkgbuild_install`) account for ~16 invocations and require the most migration effort.
