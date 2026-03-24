"""Contract tests for shared shell/bootstrap scripts."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_salt_runtime_module_exposes_required_functions():
    source = (REPO_ROOT / "scripts" / "salt-runtime.sh").read_text()

    assert "salt_runtime_prepare_dirs()" in source
    assert "salt_runtime_write_minion_config()" in source
    assert "salt_runtime_clear_stale_proc_locks()" in source


def test_salt_apply_and_validate_source_runtime_module():
    apply_source = (REPO_ROOT / "scripts" / "salt-apply.sh").read_text()
    validate_source = (REPO_ROOT / "scripts" / "salt-validate.sh").read_text()
    apply_call = 'salt_runtime_write_minion_config "${PROJECT_DIR}" "${RUNTIME_CONFIG_DIR}" apply'
    validate_call = 'salt_runtime_write_minion_config "${project_dir}" "${runtime}" validate'

    assert 'source "${SCRIPT_DIR}/salt-runtime.sh"' in apply_source
    assert 'source "${script_dir}/salt-runtime.sh"' in validate_source
    assert apply_call in apply_source
    assert validate_call in validate_source


def test_justfile_lint_delegates_to_script():
    justfile_source = (REPO_ROOT / "Justfile").read_text()
    lint_script_source = (REPO_ROOT / "scripts" / "lint-all.sh").read_text()

    assert "bash scripts/lint-all.sh" in justfile_source
    assert 'run_check "lint-jinja"' in lint_script_source
    assert 'run_check "yamllint"' in lint_script_source
