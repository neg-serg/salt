"""cmd.run compliance audit: check all cmd.run/cmd.script states against the standard.

See docs/cmd-run-standard.md for the full specification.
Violations are reported as warnings — this test does not fail CI.
Complements spec 051 which handles the actual refactoring.
"""

import importlib.util
import os
import re
import sys
import warnings

import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS_DIR = os.path.join(REPO_ROOT, "scripts")

if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import host_model  # noqa: E402

_lint_path = os.path.join(SCRIPTS_DIR, "lint-jinja.py")
_spec = importlib.util.spec_from_file_location("lint_jinja", _lint_path)
_lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_lint)

_make_render_env = _lint._make_render_env
_resolve_import_yaml = _lint._resolve_import_yaml

GUARD_KEYS = {"creates", "unless", "onlyif"}
CMD_FUNCTIONS = {"cmd.run", "cmd.script"}
EXCEPTION_PATTERN = re.compile(r"#\s*cmdrun:exception\b")


def _render_all_states():
    """Render all .sls files for the default scenario and return parsed YAML."""
    import glob

    orig = os.getcwd()
    os.chdir(REPO_ROOT)
    try:
        env = _make_render_env()
        env.globals["grains"]["host"] = "matrix-default"
        env.globals["hosts_data"] = host_model.load_hosts_yaml()
        env.globals["feature_matrix"] = host_model.load_feature_matrix()

        results = {}
        for path in sorted(glob.glob("states/*.sls")):
            rel = path.removeprefix("states/")
            try:
                with open(path) as fh:
                    source = fh.read()
                yaml_vars = _resolve_import_yaml(source)
                tmpl = env.get_template(rel)
                rendered = tmpl.render(**yaml_vars)
                data = yaml.safe_load(rendered)
                if isinstance(data, dict):
                    results[path] = data
            except Exception:
                pass  # Render failures are caught by test_render_validation.py
        return results
    finally:
        os.chdir(orig)


def _extract_cmd_states(all_states):
    """Extract all cmd.run/cmd.script states with their properties."""
    cmd_states = []
    for sls_file, states in all_states.items():
        for state_id, state_def in states.items():
            if not isinstance(state_def, dict):
                continue
            for func_name, args in state_def.items():
                if func_name not in CMD_FUNCTIONS:
                    continue
                if not isinstance(args, list):
                    continue

                props = {}
                for item in args:
                    if isinstance(item, dict):
                        props.update(item)
                    elif isinstance(item, str):
                        props.setdefault("_positional", []).append(item)

                cmd_states.append(
                    {
                        "file": sls_file,
                        "state_id": state_id,
                        "function": func_name,
                        "name": props.get("name", ""),
                        "has_shell": "shell" in props,
                        "has_guard": bool(GUARD_KEYS & set(props.keys())),
                        "has_error_handling": _check_error_handling(props),
                        "has_exception": bool(EXCEPTION_PATTERN.search(props.get("name", ""))),
                    }
                )
    return cmd_states


def _check_error_handling(props):
    """Check if a cmd.run has proper error handling."""
    name = props.get("name", "")
    # Single-line commands don't need set -eo pipefail
    lines = [
        ln for ln in name.strip().splitlines() if ln.strip() and not ln.strip().startswith("#")
    ]
    if len(lines) <= 1:
        return True
    return "set -eo pipefail" in name or "set -euo pipefail" in name


_ALL_STATES = _render_all_states()
_CMD_STATES = _extract_cmd_states(_ALL_STATES)


def test_cmdrun_audit_summary():
    """Report cmd.run compliance summary."""
    total = len(_CMD_STATES)
    if total == 0:
        return

    with_guard = sum(1 for s in _CMD_STATES if s["has_guard"])
    with_error = sum(1 for s in _CMD_STATES if s["has_error_handling"] or s["has_exception"])

    # Fully compliant = has all three
    compliant = sum(
        1 for s in _CMD_STATES if s["has_guard"] and (s["has_error_handling"] or s["has_exception"])
    )

    violations = []
    for s in _CMD_STATES:
        issues = []
        if not s["has_guard"]:
            issues.append("missing guard")
        if not s["has_error_handling"] and not s["has_exception"]:
            issues.append("missing error handling")
        if issues:
            violations.append(
                f"  {s['file']}:{s['state_id']} ({s['function']}) — {', '.join(issues)}"
            )

    report = (
        f"cmd.run audit: {compliant}/{total} compliant "
        f"(guard: {with_guard}/{total}, error-handling: {with_error}/{total})"
    )

    if violations:
        report += "\nViolations:\n" + "\n".join(violations)
        warnings.warn(report, stacklevel=1)
    else:
        # All compliant — just log
        warnings.warn(report, stacklevel=1)


def test_cmdrun_states_found():
    """Verify cmd.run states were found for auditing."""
    assert len(_CMD_STATES) > 0, "No cmd.run/cmd.script states found"


def test_cmdrun_guard_coverage():
    """Check that guard coverage is tracked."""
    total = len(_CMD_STATES)
    with_guard = sum(1 for s in _CMD_STATES if s["has_guard"])
    # Report-only: always passes
    assert total > 0
    if with_guard < total:
        missing = [s for s in _CMD_STATES if not s["has_guard"]]
        warnings.warn(
            f"Guard coverage: {with_guard}/{total} — "
            + ", ".join(f"{s['file']}:{s['state_id']}" for s in missing),
            stacklevel=1,
        )
