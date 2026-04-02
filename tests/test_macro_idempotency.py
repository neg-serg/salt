"""Macro idempotency verification: ensure all macro-generated cmd.run/cmd.script
states include idempotency guards (creates, unless, onlyif).

Validates Constitution Principle I compliance for macro-generated states.
"""

import glob
import importlib.util
import os
import sys

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

# Macro files to verify
MACRO_FILES = sorted(glob.glob(os.path.join(REPO_ROOT, "states", "_macros_*.jinja")))


def _render_state(sls_path):
    """Render a single .sls file and return parsed YAML."""
    orig = os.getcwd()
    os.chdir(REPO_ROOT)
    try:
        env = _make_render_env()
        env.globals["grains"]["host"] = "matrix-default"
        env.globals["hosts_data"] = host_model.load_hosts_yaml()
        env.globals["feature_matrix"] = host_model.load_feature_matrix()

        rel = sls_path.removeprefix("states/")
        with open(sls_path) as fh:
            source = fh.read()
        yaml_vars = _resolve_import_yaml(source)
        tmpl = env.get_template(rel)
        rendered = tmpl.render(**yaml_vars)
        return yaml.safe_load(rendered) or {}
    except Exception:
        return {}
    finally:
        os.chdir(orig)


def _find_macro_consumers():
    """Find .sls files that import any macro file."""
    macro_basenames = {os.path.basename(f) for f in MACRO_FILES}
    consumers = []
    for sls_path in sorted(glob.glob(os.path.join(REPO_ROOT, "states", "*.sls"))):
        with open(sls_path) as fh:
            source = fh.read()
        for name in macro_basenames:
            if name in source:
                consumers.append(sls_path)
                break
    return consumers


def _extract_cmd_states(states_dict):
    """Extract cmd.run/cmd.script states with their guard status."""
    results = []
    for state_id, state_def in states_dict.items():
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
            has_guard = bool(GUARD_KEYS & set(props.keys()))
            results.append(
                {
                    "state_id": state_id,
                    "function": func_name,
                    "has_guard": has_guard,
                }
            )
    return results


# Collect all macro-consuming states and their cmd.run entries
_CONSUMERS = _find_macro_consumers()
_ALL_CMD_STATES = []
for _sls in _CONSUMERS:
    _states = _render_state(_sls)
    _rel = os.path.relpath(_sls, REPO_ROOT)
    for _entry in _extract_cmd_states(_states):
        _entry["file"] = _rel
        _ALL_CMD_STATES.append(_entry)


def test_macro_files_exist():
    """Verify macro files are found."""
    assert len(MACRO_FILES) > 0, "No _macros_*.jinja files found"


def test_macro_consumers_found():
    """Verify states that use macros are found."""
    assert len(_CONSUMERS) > 0, "No .sls files importing macros found"


def test_macro_generated_states_have_guards():
    """All macro-generated cmd.run/cmd.script states must have idempotency guards."""
    missing = [s for s in _ALL_CMD_STATES if not s["has_guard"]]
    total = len(_ALL_CMD_STATES)
    guarded = total - len(missing)

    if missing:
        details = "\n".join(f"  {s['file']}:{s['state_id']} ({s['function']})" for s in missing)
        # Report as assertion failure — macro guards are Constitution Principle I
        assert False, f"Macro idempotency: {guarded}/{total} guarded. Missing guards:\n{details}"
