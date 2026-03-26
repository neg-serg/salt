from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_zen_browser_state_vendors_supergradient_into_profile():
    text = read("states/zen_browser.sls")
    assert "zen_supergradient_theme" in text
    assert "af7ee14f-e9d4-4806-8438-c59b02b77715" in text
    assert "file.recurse" in text


def test_zen_user_js_sets_supergradient_defaults():
    text = read("dotfiles/dot_config/zen-browser/user.js")
    assert 'user_pref("theme.supergradient.preset", "AmethystClaret");' in text
    assert 'user_pref("theme.supergradient.intensity", "Normal");' in text
    assert 'user_pref("uc.supergradient.desaturate", false);' in text
    assert 'user_pref("uc.supergradient.use-accent-color", false);' in text
    assert 'user_pref("uc.supergradient.switch-colors", false);' in text


def test_supergradient_assets_are_ignored_by_chezmoi_and_keep_metadata():
    ignore = read("dotfiles/.chezmoiignore")
    theme = read(
        "dotfiles/dot_config/zen-browser/zen-themes/af7ee14f-e9d4-4806-8438-c59b02b77715/theme.json"
    )
    prefs = read(
        "dotfiles/dot_config/zen-browser/zen-themes/"
        "af7ee14f-e9d4-4806-8438-c59b02b77715/preferences.json"
    )
    assert ".config/zen-browser/zen-themes/" in ignore
    assert '"name": "SuperGradient"' in theme
    assert '"defaultValue": "AmethystClaret"' in prefs
