"""Contract tests for decomposed state layout and recursive tooling coverage."""

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_video_ai_root_state_includes_thematic_children():
    source = (REPO_ROOT / "states" / "video_ai.sls").read_text()

    assert "include:" in source
    assert "- video_ai.base" in source
    assert "- video_ai.models" in source
    assert "- video_ai.workflows" in source
    assert "- video_ai.runners" in source


def test_desktop_root_state_includes_thematic_children():
    source = (REPO_ROOT / "states" / "desktop.sls").read_text()

    assert "include:" in source
    assert "- desktop.system" in source
    assert "- desktop.packages" in source
    assert "- desktop.hyprland" in source
    assert "- desktop.user" in source


def test_recursive_state_tooling_is_enabled_for_subdirectories():
    lint_source = (REPO_ROOT / "scripts" / "lint-jinja.py").read_text()
    profiler_source = (REPO_ROOT / "scripts" / "state-profiler.py").read_text()
    index_source = (REPO_ROOT / "scripts" / "index-salt.py").read_text()

    assert 'glob.glob("states/**/*.sls", recursive=True)' in lint_source
    assert 'glob.glob("states/**/*.sls", recursive=True)' in profiler_source
    assert '"**", "*.sls"' in index_source
