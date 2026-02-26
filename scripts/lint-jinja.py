#!/usr/bin/env python3
"""Lint Salt state files: Jinja2 syntax, YAML validity, duplicate state IDs,
naming conventions, unused imports, require resolution, dangling includes."""

import ast
import collections
import getpass
import glob
import os
import re
import sys

import jinja2
import jinja2.ext
import yaml

# --- Salt-specific Jinja2 tags ---
# Salt adds tags like {% import_yaml %}, {% load_yaml %} etc.
# Register them as no-op extensions so jinja2.parse() doesn't choke.


class SaltTagExtension(jinja2.ext.Extension):
    tags = {"import_yaml", "load_yaml", "import_json", "load_json", "import_text"}

    def parse(self, parser):
        tag = next(parser.stream)
        # Consume everything until block_end and return empty output
        while parser.stream.current.test("block_end") is False:
            next(parser.stream)
        return jinja2.nodes.Output([], lineno=tag.lineno)


def check_jinja_syntax(files):
    """Check Jinja2 syntax for .sls and .jinja files."""
    env = jinja2.Environment(extensions=["jinja2.ext.do", SaltTagExtension])
    errors = 0
    for f in files:
        try:
            with open(f) as fh:
                env.parse(fh.read())
        except jinja2.TemplateSyntaxError as e:
            print(f"\033[31mJinja: {f}:{e.lineno}: {e.message}\033[0m")
            errors += 1
    return errors


def _resolve_import_yaml(source, states_dir="states"):
    """Pre-scan template source for {% import_yaml %} and load the referenced files.

    Returns a dict of {var_name: loaded_data} to inject into the render context.
    """
    yaml_vars = {}
    for match in re.finditer(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+(\w+)", source):
        rel_path, var_name = match.group(1), match.group(2)
        yaml_path = f"{states_dir}/{rel_path}"
        try:
            with open(yaml_path) as fh:
                yaml_vars[var_name] = yaml.safe_load(fh.read())
        except (FileNotFoundError, yaml.YAMLError):
            pass
    return yaml_vars


def _deep_enable(d):
    """Recursively set all False booleans to True."""
    return {
        k: _deep_enable(v) if isinstance(v, dict) else (True if v is False else v)
        for k, v in d.items()
    }


def _enable_all_features(d):
    """Enable all feature flags in host config for maximum lint coverage."""
    if not isinstance(d, dict):
        return d
    result = d.copy()
    if "features" in result and isinstance(result["features"], dict):
        result["features"] = _deep_enable(result["features"])
    return result


class _MockSalt:
    """Mock salt function namespace so host_config.jinja can call slsutil.merge."""

    def __getitem__(self, key):
        if key == "slsutil.merge":
            return self._merge
        return lambda *a, **kw: ""

    @staticmethod
    def _merge(base, override, strategy="recurse"):
        if strategy == "recurse":
            merged = _recursive_merge(base, override)
        else:
            merged = base.copy()
            merged.update(override)
        return _enable_all_features(merged)


def _fallback_host():
    """Build a minimal fallback host config from the current environment."""
    user = os.environ.get("USER", getpass.getuser())
    home = os.path.expanduser("~")
    return {"user": user, "home": home, "pkg_list": "/var/cache/salt/pacman_installed.txt"}


def _build_lint_host():
    """Build a synthetic host config with all features enabled for linting.

    Parses defaults from host_config.jinja, enables all feature flags, and
    adds derived fields.  This is needed because macros in _macros_pkg.jinja
    and _macros_service.jinja reference ``host`` directly (not via import).
    """
    try:
        with open("states/host_config.jinja") as fh:
            source = fh.read()
    except FileNotFoundError:
        return _fallback_host()
    defaults_src = _extract_dict_literal(source, "defaults")
    if not defaults_src:
        return _fallback_host()
    defaults_src = re.sub(r"grains\[.*?\]", "'lint-check'", defaults_src)
    try:
        defaults = ast.literal_eval(defaults_src)
    except (ValueError, SyntaxError):
        return _fallback_host()
    host = _enable_all_features(defaults)
    host["runtime_dir"] = f"/run/user/{host['uid']}"
    host["pkg_list"] = "/var/cache/salt/pacman_installed.txt"
    host["project_dir"] = host["home"] + "/src/salt"
    return host


def _make_render_env():
    """Create a Jinja2 environment with mock salt/grains for full template rendering."""
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader("states"),
        extensions=["jinja2.ext.do", SaltTagExtension],
        undefined=jinja2.Undefined,
    )
    host = _build_lint_host()
    env.globals["grains"] = {"host": "lint-check"}
    env.globals["salt"] = _MockSalt()
    # Macros in _macros_pkg/_macros_service access these directly (not via import)
    env.globals["host"] = host
    return env


def check_duplicate_state_ids(sls_files):
    """Render .sls files with mock context and check for duplicate state IDs.

    Returns (errors, render_ok, all_ids, rendered_docs) where rendered_docs
    maps filepath → list of parsed YAML documents (for requisite checking).
    """
    env = _make_render_env()
    all_ids = []
    rendered_docs = {}
    render_ok = 0
    for path in sls_files:
        name = path.removeprefix("states/")
        try:
            t = env.get_template(name)
            # Pre-load any {% import_yaml %} data so templates render correctly
            with open(path) as fh:
                yaml_vars = _resolve_import_yaml(fh.read())
            rendered = t.render(**yaml_vars)
            docs = []
            for doc in yaml.safe_load_all(rendered):
                if doc and isinstance(doc, dict):
                    for key in doc:
                        if key not in _SALT_DIRECTIVES:
                            all_ids.append(key)
                    docs.append(doc)
            rendered_docs[path] = docs
            render_ok += 1
        except Exception:
            # Files using Salt-only features won't render
            pass

    dupes = [k for k, v in collections.Counter(all_ids).items() if v > 1]
    errors = 0
    for d in dupes:
        print(f"\033[31mDuplicate state ID: {d}\033[0m")
        errors += 1
    return errors, render_ok, all_ids, rendered_docs


_RESERVED_PREFIXES = ("install_", "build_")
_RAW_STATE_ID_RE = re.compile(r"^([A-Za-z_][\w.-]*)\s*:")


def check_state_id_naming(sls_files, rendered_ids):
    """Check state ID naming conventions.

    Rules:
    - IDs must not contain '/' (file paths should use name: parameter)
    - Reserved prefixes (install_*, build_*) in raw .sls source should only
      come from macros, not appear as hand-written state IDs
    """
    errors = 0

    # Check rendered IDs for file-path-like patterns (3+ segments, e.g. /etc/foo/bar)
    # Shallow paths like /mnt/zero are OK (common for mount state IDs).
    # Font directory paths from download_font_zip macro are also expected.
    seen = set()
    for sid in rendered_ids:
        if sid.count("/") >= 3 and sid not in seen:
            if "/.local/share/fonts/" in sid:
                continue
            seen.add(sid)
            print(
                f"\033[31mNaming: '{sid}'"
                f" — use descriptive name + name: parameter, not file path\033[0m"
            )
            errors += 1

    # Check raw .sls for inline use of reserved prefixes
    for path in sls_files:
        with open(path) as fh:
            for lineno, line in enumerate(fh, 1):
                m = _RAW_STATE_ID_RE.match(line)
                if m:
                    sid = m.group(1)
                    if any(sid.startswith(p) for p in _RESERVED_PREFIXES):
                        print(
                            f"\033[33mNaming: {path}:{lineno}: '{sid}'"
                            f" — install_*/build_* prefix reserved for macros\033[0m"
                        )
                        errors += 1

    return errors


def _extract_dict_literal(source, var_name):
    """Extract a dict literal from {% set var_name = {...} %}."""
    m = re.search(rf"\{{%-?\s*set\s+{var_name}\s*=\s*", source)
    if not m:
        return None
    start = source.index("{", m.end())
    depth = 0
    for i in range(start, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[start : i + 1]
    return None


def _recursive_merge(base, override):
    """Recursive dict merge mimicking slsutil.merge(strategy='recurse')."""
    result = base.copy()
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _recursive_merge(result[k], v)
        else:
            result[k] = v
    return result


def _check_unknown_keys(config, defaults, hostname, prefix=""):
    """Check for keys in host config that don't exist in defaults."""
    errors = 0
    for k, v in config.items():
        path = f"{prefix}.{k}" if prefix else k
        if k not in defaults:
            print(f"\033[31mHost config: '{hostname}': unknown key '{path}'\033[0m")
            errors += 1
        elif isinstance(v, dict) and isinstance(defaults.get(k), dict):
            errors += _check_unknown_keys(v, defaults[k], hostname, path)
    return errors


_VALID_CPU_VENDORS = {"amd", "intel"}
_KVM_MODULES = {"amd": "kvm_amd", "intel": "kvm_intel"}
_DISPLAY_RE = re.compile(r"^\d+x\d+@\d+$")


def check_host_config():
    """Validate host_config.jinja: field types, allowed values, unknown keys."""
    try:
        with open("states/host_config.jinja") as fh:
            source = fh.read()
    except FileNotFoundError:
        return 0

    defaults_src = _extract_dict_literal(source, "defaults")
    hosts_src = _extract_dict_literal(source, "hosts")
    if not defaults_src or not hosts_src:
        print("\033[31mHost config: cannot locate defaults/hosts dicts\033[0m")
        return 1

    # Replace non-literal expressions so ast.literal_eval works
    defaults_src = re.sub(r"grains\[.*?\]", "'__grains__'", defaults_src)

    try:
        defaults = ast.literal_eval(defaults_src)
    except (ValueError, SyntaxError) as e:
        print(f"\033[31mHost config: cannot parse defaults: {e}\033[0m")
        return 1
    try:
        hosts = ast.literal_eval(hosts_src)
    except (ValueError, SyntaxError) as e:
        print(f"\033[31mHost config: cannot parse hosts: {e}\033[0m")
        return 1

    errors = 0
    for hostname, config in hosts.items():
        merged = _recursive_merge(defaults, config)

        # Unknown keys (typo protection)
        errors += _check_unknown_keys(config, defaults, hostname)

        # cpu_vendor must be amd or intel
        cpu = merged.get("cpu_vendor")
        if cpu not in _VALID_CPU_VENDORS:
            print(
                f"\033[31mHost config: '{hostname}':"
                f" cpu_vendor '{cpu}' not in {_VALID_CPU_VENDORS}\033[0m"
            )
            errors += 1

        # kvm_module must match cpu_vendor
        expected_kvm = _KVM_MODULES.get(cpu)
        if expected_kvm and merged.get("kvm_module") != expected_kvm:
            print(
                f"\033[31mHost config: '{hostname}':"
                f" kvm_module '{merged.get('kvm_module')}' doesn't match"
                f" cpu_vendor '{cpu}' (expected '{expected_kvm}')\033[0m"
            )
            errors += 1

        # display format: WxH@Hz (if set)
        display = merged.get("display", "")
        if display and not _DISPLAY_RE.match(display):
            print(
                f"\033[31mHost config: '{hostname}':"
                f" display '{display}' doesn't match WxH@Hz format\033[0m"
            )
            errors += 1

        # hostname field should match dict key
        h = merged.get("hostname")
        if h not in (hostname, "__grains__"):
            print(
                f"\033[31mHost config: '{hostname}':"
                f" hostname field '{h}' doesn't match dict key\033[0m"
            )
            errors += 1

        # Numeric fields
        for field in ("uid", "greetd_scale", "cursor_size"):
            if not isinstance(merged.get(field), int):
                print(
                    f"\033[31mHost config: '{hostname}':"
                    f" {field} must be int, got {type(merged.get(field)).__name__}\033[0m"
                )
                errors += 1

    return errors


def check_yaml_configs(config_files):
    """Validate YAML syntax in config files."""
    errors = 0
    for f in config_files:
        try:
            with open(f) as fh:
                yaml.safe_load(fh.read())
        except yaml.YAMLError as e:
            print(f"\033[31mYAML: {f}: {e}\033[0m")
            errors += 1
    return errors


# --- Cross-file validation checks ---

_IMPORT_FROM_RE = re.compile(r"\{%-?\s*from\s+['\"]([^'\"]+)['\"]\s+import\s+(.+?)\s*-?%\}")
_IMPORT_YAML_RE = re.compile(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+(\w+)\s*-?%\}")
_REQUISITE_KEYS = frozenset(
    {
        "require",
        "watch",
        "onchanges",
        "onfail",
        "prereq",
        "require_in",
        "watch_in",
        "onchanges_in",
        "onfail_in",
    }
)
# Salt directives that are top-level YAML keys but not state IDs
_SALT_DIRECTIVES = frozenset({"include", "extend"})


def check_unused_imports(sls_files):
    """Detect imported but unused macros/variables in .sls files."""
    warnings = 0
    for path in sls_files:
        with open(path) as fh:
            source = fh.read()

        # Collect all imports: (source_file, local_name)
        imports = []
        for m in _IMPORT_FROM_RE.finditer(source):
            src_file = m.group(1)
            for item in m.group(2).split(","):
                item = item.strip()
                if " as " in item:
                    _, alias = item.split(" as ", 1)
                    imports.append((src_file, alias.strip()))
                else:
                    imports.append((src_file, item.strip()))

        for m in _IMPORT_YAML_RE.finditer(source):
            imports.append((m.group(1), m.group(2)))

        if not imports:
            continue

        # Remove import lines from source to get the body
        body = _IMPORT_FROM_RE.sub("", source)
        body = _IMPORT_YAML_RE.sub("", body)

        for src_file, name in imports:
            if not re.search(r"\b" + re.escape(name) + r"\b", body):
                print(f"\033[33mUnused import: {path}: '{name}' from '{src_file}'\033[0m")
                warnings += 1

    return warnings


def check_require_resolve(rendered_docs, global_ids):
    """Validate that all requisite references point to existing state IDs."""
    valid_ids = set(global_ids)
    errors = 0

    for filepath, docs in rendered_docs.items():
        for doc in docs:
            if not doc or not isinstance(doc, dict):
                continue
            for state_id, state_body in doc.items():
                if state_id in _SALT_DIRECTIVES:
                    continue
                if not isinstance(state_body, dict):
                    continue
                for mod_func, directives in state_body.items():
                    if not isinstance(directives, list):
                        continue
                    for directive in directives:
                        if not isinstance(directive, dict):
                            continue
                        for req_key in _REQUISITE_KEYS:
                            if req_key not in directive:
                                continue
                            req_list = directive[req_key]
                            if not isinstance(req_list, list):
                                continue
                            for item in req_list:
                                if not isinstance(item, dict):
                                    continue
                                for req_type, req_id in item.items():
                                    req_id = str(req_id)
                                    if req_id not in valid_ids:
                                        print(
                                            f"\033[31mRequire: {filepath}:"
                                            f" {state_id} → {req_type}:"
                                            f" {req_id} (not found)\033[0m"
                                        )
                                        errors += 1

    return errors


def check_dangling_includes(sls_files):
    """Verify that include: list entries point to existing .sls files."""
    errors = 0
    for path in sls_files:
        with open(path) as fh:
            source = fh.read()

        in_include = False
        for line in source.splitlines():
            stripped = line.strip()
            if stripped == "include:":
                in_include = True
                continue
            if not in_include:
                continue
            # Still inside include block
            if stripped.startswith("- "):
                name = stripped[2:].strip()
                # Strip inline comments
                if " #" in name:
                    name = name[: name.index(" #")].strip()
                if "#" in name and name.startswith("#"):
                    continue
                if name:
                    target = f"states/{name.replace('.', '/')}.sls"
                    if not os.path.isfile(target):
                        print(
                            f"\033[31mDangling include: {path}:"
                            f" '{name}' → {target} not found\033[0m"
                        )
                        errors += 1
            elif stripped.startswith("#") or stripped == "":
                continue
            else:
                # Non-list, non-comment line → end of include block
                in_include = False

    return errors


# Patterns indicating the cmd.run command accesses the network
_NETWORK_CMD_RE = re.compile(
    r"""
    \bcurl\s          # curl downloads
    | \bwget\s        # wget downloads
    | \bgit\s+clone\b # git clone
    | \bgit\s+pull\b  # git pull
    | \bpacman\s+-S\b # pacman install (not -Q queries)
    | \bparu\s        # AUR helper (always downloads)
    | \bmakepkg\b     # builds from AUR (downloads sources)
    | \bcargo\s+install\b
    | \bpip\s+install\b
    | \bnpm\s+install\b
    """,
    re.VERBOSE,
)
# Curl to localhost/127.0.0.1 is a health check, not a network download
_LOCALHOST_CURL_RE = re.compile(r"\bcurl\s.*\b(127\.0\.0\.1|localhost)\b")


def check_network_resilience(rendered_docs):
    """Check that cmd.run states with network commands have retry and parallel.

    Reports warnings (not errors) since some states intentionally omit parallel
    due to require chains or CPU-heavy builds.
    """
    warnings = 0

    for filepath, docs in rendered_docs.items():
        for doc in docs:
            if not doc or not isinstance(doc, dict):
                continue
            for state_id, state_body in doc.items():
                if state_id in _SALT_DIRECTIVES:
                    continue
                if not isinstance(state_body, dict):
                    continue
                for mod_func, directives in state_body.items():
                    if mod_func not in ("cmd.run", "cmd.script"):
                        continue
                    if not isinstance(directives, list):
                        continue

                    cmd_text = ""
                    has_retry = False
                    has_parallel = False
                    has_require = False

                    for d in directives:
                        if not isinstance(d, dict):
                            continue
                        if "name" in d:
                            cmd_text = str(d["name"])
                        if "retry" in d:
                            has_retry = True
                        if "parallel" in d:
                            has_parallel = True
                        if "require" in d:
                            has_require = True

                    if not _NETWORK_CMD_RE.search(cmd_text):
                        continue
                    # Exclude localhost health checks (curl to 127.0.0.1/localhost)
                    if _LOCALHOST_CURL_RE.search(cmd_text) and not re.search(
                        r"\b(wget|git\s+clone|pacman\s+-S|paru|makepkg)\b", cmd_text
                    ):
                        continue

                    if not has_retry:
                        print(
                            f"\033[33mNetwork: {filepath}:"
                            f" '{state_id}' — network command without retry:\033[0m"
                        )
                        warnings += 1
                    if not has_parallel and not has_require:
                        print(
                            f"\033[33mNetwork: {filepath}:"
                            f" '{state_id}' — network command without"
                            f" parallel: True (and no require: chain)\033[0m"
                        )
                        warnings += 1

    return warnings


def check_data_integrity():
    """Validate YAML data files: required keys, version cross-references."""
    errors = 0

    try:
        with open("states/data/versions.yaml") as fh:
            versions = yaml.safe_load(fh) or {}
    except (FileNotFoundError, yaml.YAMLError):
        return 0

    # Required keys by section type
    required_keys = {
        "curl_extract_zip": ["url"],
        "curl_extract_tar": ["url", "binary_pattern"],
        "download_zip": ["url"],
    }

    # Data files with versioned tool definitions
    data_files = [
        "states/data/installers.yaml",
        "states/data/installers_desktop.yaml",
        "states/data/fonts.yaml",
    ]

    for data_file in data_files:
        try:
            with open(data_file) as fh:
                data = yaml.safe_load(fh) or {}
        except (FileNotFoundError, yaml.YAMLError):
            continue

        basename = os.path.basename(data_file)

        for section, entries in data.items():
            if not isinstance(entries, dict):
                continue

            # Check required keys
            if section in required_keys:
                for name, opts in entries.items():
                    if not isinstance(opts, dict):
                        continue
                    for key in required_keys[section]:
                        if key not in opts:
                            print(
                                f"\033[31mData: {basename}:"
                                f" {section}.{name} missing required key"
                                f" '{key}'\033[0m"
                            )
                            errors += 1

            # Check ${VER} references have matching versions.yaml entry
            for name, opts in entries.items():
                url = ""
                if isinstance(opts, str):
                    url = opts
                elif isinstance(opts, dict):
                    url = opts.get("url", "")

                if "${VER}" in url:
                    ver_key = name.replace("-", "_")
                    if ver_key not in versions:
                        print(
                            f"\033[31mData: {basename}:"
                            f" {section}.{name} uses ${{VER}} but"
                            f" '{ver_key}' not in versions.yaml\033[0m"
                        )
                        errors += 1

    return errors


def main():
    sls_files = sorted(glob.glob("states/*.sls"))
    jinja_files = sorted(glob.glob("states/*.jinja"))
    yaml_configs = sorted(
        glob.glob("states/configs/*.yaml")
        + glob.glob("states/configs/*.yml")
        + glob.glob("states/data/*.yaml")
    )
    all_jinja = sls_files + jinja_files

    total_errors = 0
    total_warnings = 0

    # 1. Jinja2 syntax
    jinja_errors = check_jinja_syntax(all_jinja)
    total_errors += jinja_errors
    print(f"Jinja2 syntax: {len(all_jinja)} files, {jinja_errors} errors")

    # 2. Duplicate state IDs (also collects rendered docs for later checks)
    dupe_errors, rendered, all_ids, rendered_docs = check_duplicate_state_ids(sls_files)
    total_errors += dupe_errors
    print(f"State IDs: {rendered} files rendered, {dupe_errors} duplicates")

    # 3. State ID naming conventions
    naming_errors = check_state_id_naming(sls_files, all_ids)
    total_errors += naming_errors
    print(f"State ID naming: {naming_errors} violations")

    # 4. Host config validation
    host_errors = check_host_config()
    total_errors += host_errors
    print(f"Host config: {host_errors} errors")

    # 5. YAML config validation
    if yaml_configs:
        yaml_errors = check_yaml_configs(yaml_configs)
        total_errors += yaml_errors
        print(f"YAML configs: {len(yaml_configs)} files, {yaml_errors} errors")

    # 6. Unused imports (warning, not error)
    import_warnings = check_unused_imports(sls_files)
    total_warnings += import_warnings
    print(f"Unused imports: {import_warnings} warnings")

    # 7. Require/watch/onchanges resolution
    require_errors = check_require_resolve(rendered_docs, all_ids)
    total_errors += require_errors
    print(f"Require resolve: {require_errors} errors")

    # 8. Dangling includes
    include_errors = check_dangling_includes(sls_files)
    total_errors += include_errors
    print(f"Dangling includes: {include_errors} errors")

    # 9. Data file integrity (required keys, version references)
    data_errors = check_data_integrity()
    total_errors += data_errors
    print(f"Data integrity: {data_errors} errors")

    # 10. Network resilience (retry + parallel on network commands)
    network_warnings = check_network_resilience(rendered_docs)
    total_warnings += network_warnings
    print(f"Network resilience: {network_warnings} warnings")

    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()
