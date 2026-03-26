from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_hypr_browser_binding_prefers_zen_and_keeps_floorp_secondary():
    text = read("dotfiles/dot_config/hypr/bindings/apps.conf")
    primary = 'bind = $M4, w, exec, raise --match "class:regex=^zen$" --launch zen-browser'
    secondary = (
        "bind = $M4+$S, w, exec, raise --match "
        '"class:regex=^(floorp|one\\.ablaze\\.floorp|floorpdeveloperedition)$" '
        "--launch floorp"
    )
    assert primary in text
    assert secondary in text


def test_wayfire_browser_binding_prefers_zen_and_keeps_floorp_secondary():
    text = read("dotfiles/dot_config/wayfire.ini")
    primary = 'command_browser = raise --match "class:regex=^zen$" --launch zen-browser'
    secondary = (
        "command_browser_floorp = raise --match "
        '"class:regex=^(floorp|one\\.ablaze\\.floorp|floorpdeveloperedition)$" '
        "--launch floorp"
    )
    assert primary in text
    assert secondary in text


def test_wlr_which_key_browser_menu_prefers_zen_and_keeps_floorp_secondary():
    text = read("dotfiles/dot_config/wlr-which-key/config.yaml")
    assert 'cmd: raise --match "class:regex=^zen$" --launch zen-browser' in text
    assert '- key: "W"' in text
    assert "desc: Floorp Browser" in text
    secondary = (
        "cmd: raise --match "
        '"class:regex=^(floorp|one\\\\.ablaze\\\\.floorp|floorpdeveloperedition)$" '
        "--launch floorp"
    )
    assert secondary in text
