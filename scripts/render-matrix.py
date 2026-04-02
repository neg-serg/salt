#!/usr/bin/env python3
"""Render Salt states for each feature-matrix host scenario.

Loads states/data/feature_matrix.yaml and renders every top-level states/*.sls
file with recursive include support from `states/**/*.sls` using the same Jinja
loader roots as production rendering.
grains['host'] set to the scenario's name.  Ensures all feature combinations
template correctly (catches missing imports/macros before deployment).
"""

import glob
import importlib.util
import os
import sys

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

import host_model  # noqa: E402

# lint-jinja.py has a hyphenated name — must use importlib.util
_lint_path = os.path.join(SCRIPTS_DIR, "lint-jinja.py")
_spec = importlib.util.spec_from_file_location("lint_jinja", _lint_path)
if not _spec:  # pragma: no cover - defensive
    raise ImportError("Cannot load lint-jinja.py spec")
_lint = importlib.util.module_from_spec(_spec)
if not _spec.loader:  # pragma: no cover - defensive
    raise ImportError("Cannot load lint-jinja.py loader")
_spec.loader.exec_module(_lint)  # type: ignore[attr-defined]

_make_render_env = _lint._make_render_env
_resolve_import_yaml = _lint._resolve_import_yaml


def _load_global_yaml_vars():
    data = {}
    data["hosts_data"] = host_model.load_hosts_yaml()
    data["feature_matrix"] = host_model.load_feature_matrix()
    return data


GLOBAL_YAML_VARS = _load_global_yaml_vars()


def load_matrix():
    data = host_model.load_feature_matrix()
    if not data:
        return []
    for entry in data:
        name = entry.get("name")
        if not name:
            raise SystemExit("feature_matrix entries require 'name'")
    return data


def render_for_scenario(env, scenario_name, sls_files):
    env.globals["grains"]["host"] = scenario_name
    env.globals["hosts_data"] = GLOBAL_YAML_VARS.get("hosts_data", {})
    env.globals["feature_matrix"] = GLOBAL_YAML_VARS.get("feature_matrix", [])
    errors = []
    for path in sls_files:
        rel = path.removeprefix("states/")
        try:
            template = env.get_template(rel)
            with open(path) as fh:
                yaml_vars = _resolve_import_yaml(fh.read())
            render_vars = GLOBAL_YAML_VARS.copy()
            render_vars.update(yaml_vars)
            template.render(**render_vars)
        except Exception as exc:  # noqa: BLE001 (surface template errors)
            errors.append((path, exc))
    return errors


def render_all_states():
    """Render all states for all matrix scenarios, returning structured results.

    Returns list of dicts: {file, scenario, success, error}
    """
    matrix = load_matrix()
    if not matrix:
        return []

    sls_files = sorted(glob.glob("states/*.sls"))
    results = []

    for entry in matrix:
        name = entry.get("name")
        env = _make_render_env()
        errors = render_for_scenario(env, name, sls_files)
        error_files = {path for path, _ in errors}
        for path in sls_files:
            if path in error_files:
                exc = next(e for p, e in errors if p == path)
                results.append(
                    {"file": path, "scenario": name, "success": False, "error": str(exc)}
                )
            else:
                results.append({"file": path, "scenario": name, "success": True, "error": None})

    return results


def main():
    matrix = load_matrix()
    if not matrix:
        print("No feature matrix entries found; nothing to render")
        return

    sls_files = sorted(glob.glob("states/*.sls"))
    overall_errors = 0

    for entry in matrix:
        name = entry.get("name")
        description = entry.get("description", "")
        env = _make_render_env()
        errors = render_for_scenario(env, name, sls_files)
        if errors:
            overall_errors += len(errors)
            print(f"\n[FAIL] {name}: {len(errors)} template error(s)")
            if description:
                print(f"       {description}")
            for path, exc in errors:
                print(f"    - {path}: {exc}")
        else:
            desc = f" – {description}" if description else ""
            print(f"[OK] {name}{desc}")

    if overall_errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
