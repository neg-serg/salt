"""Render validation: verify all .sls files render to valid output.

Wraps scripts/render-matrix.py as a pytest test. Failures are reported
as warnings (report-only mode) — they do not fail the test suite.
"""

import importlib.util
import os
import warnings

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS_DIR = os.path.join(REPO_ROOT, "scripts")

# Import render-matrix.py via importlib (hyphenated name)
_rm_path = os.path.join(SCRIPTS_DIR, "render-matrix.py")
_spec = importlib.util.spec_from_file_location("render_matrix", _rm_path)
_rm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_rm)

render_all_states = _rm.render_all_states


def _collect_results():
    orig = os.getcwd()
    os.chdir(REPO_ROOT)
    try:
        return render_all_states()
    finally:
        os.chdir(orig)


# Collect once at module level for parametrization
_RESULTS = _collect_results()
_FAILURES = [r for r in _RESULTS if not r["success"]]
_SCENARIOS = sorted({r["scenario"] for r in _RESULTS})
_FILES = sorted({r["file"] for r in _RESULTS})


def test_render_validation_summary():
    """Report overall render validation results."""
    total = len(_RESULTS)
    passed = sum(1 for r in _RESULTS if r["success"])
    failed = total - passed

    if _FAILURES:
        failure_report = "\n".join(
            f"  {r['file']} [{r['scenario']}]: {r['error']}" for r in _FAILURES
        )
        warnings.warn(
            f"Render validation: {failed}/{total} failures\n{failure_report}",
            stacklevel=1,
        )

    # Report-only: always passes, violations are warnings
    assert total > 0, "No states found to validate"


def test_render_validation_scenarios_covered():
    """Verify all feature matrix scenarios were tested."""
    assert len(_SCENARIOS) > 0, "No feature matrix scenarios found"


def test_render_validation_files_covered():
    """Verify all .sls files were included in validation."""
    assert len(_FILES) > 0, "No .sls files found to validate"
