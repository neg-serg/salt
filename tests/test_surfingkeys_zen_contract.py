from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_zen_extension_manifest_keeps_surfingkeys():
    text = read("states/data/zen_browser.yaml")
    assert "slug: surfingkeys_ff" in text
    assert "Helper-dependent Zen workflow" in text


def test_zen_browser_state_resets_extension_metadata_when_profile_changes():
    text = read("states/zen_browser.sls")
    assert "zen_reset_extensions_json" in text
    assert "- name: {{ zen_profile }}/extensions.json" in text
    assert "- file: zen_user_js" in text


def test_surfingkeys_config_keeps_zen_helper_actions():
    text = read("dotfiles/dot_config/surfingkeys.js")
    assert "Zen Browser: focus address bar via local helper" in text
    assert "http://localhost:18888/focus" in text
    assert "http://localhost:18888/blank.html" in text
    assert "url: url" in text
    assert "{ tab: { tabbed: true, active: true }, url });" not in text


def test_helper_server_exposes_required_endpoints_for_zen_flow():
    text = read("dotfiles/dot_local/bin/executable_surfingkeys-server")
    double_quoted = 'ALLOWED_PATHS = {"/focus", "/blank.html"}'
    single_quoted = "ALLOWED_PATHS = {'/focus', '/blank.html'}"
    assert double_quoted in text or single_quoted in text
    assert 'self.send_header("Cache-Control", "no-store")' in text
    assert "subprocess.run(" in text
