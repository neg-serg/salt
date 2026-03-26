"""Contract tests for managed Hiddify automation."""

import json
import os
import stat
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_system_description_includes_hiddify_state_by_default():
    source = (REPO_ROOT / "states" / "system_description.sls").read_text()

    assert "host.features.network.get('hiddify', True)" in source
    assert "- hiddify" in source


def test_hiddify_state_removes_legacy_appimage_and_prefers_hiddify_next():
    source = (REPO_ROOT / "states" / "hiddify.sls").read_text()

    assert "Hiddify.AppImage" in source
    assert "hiddify-official.desktop" in source
    assert "hiddify.desktop" in source
    assert "/usr/lib/hiddify/hiddify" in source
    assert "xdg-mime default hiddify.desktop x-scheme-handler/hiddify" in source
    assert "/usr/lib/hiddify/HiddifyCli" in source
    assert "cap_net_admin,cap_net_bind_service,cap_net_raw=ep" in source
    assert "setcap" in source
    assert "getcap" in source


def test_hiddify_state_keeps_compatibility_wrappers_and_profile_data():
    source = (REPO_ROOT / "states" / "hiddify.sls").read_text()

    assert "{{ home }}/.local/bin/hiddify-launch" not in source
    assert "{{ home }}/.local/bin/hiddify-fix-loopback" not in source
    assert "{{ home }}/.local/share/app.hiddify.com" not in source


def test_hiddify_wrapper_launches_system_binary_after_loopback_fix():
    source = (
        REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_hiddify-launch"
    ).read_text()

    assert '"$HOME/.local/bin/hiddify-fix-loopback" || true' in source
    assert "for _ in {1..40}; do" in source
    assert "sleep 0.25" in source
    assert 'exec hiddify "$@"' in source


def test_hiddify_local_desktop_uses_wrapper_exec():
    source = (
        REPO_ROOT / "dotfiles" / "dot_local" / "share" / "applications" / "hiddify.desktop"
    ).read_text()

    assert "Exec=/home/neg/.local/bin/hiddify-launch %U" in source
    assert "MimeType=x-scheme-handler/hiddify" in source


def test_hiddify_fix_loopback_removes_ipv6_loopback_inbounds_and_rewrites_kde_proxy():
    script = REPO_ROOT / "dotfiles" / "dot_local" / "bin" / "executable_hiddify-fix-loopback"

    with tempfile.TemporaryDirectory() as tmpdir:
        home = Path(tmpdir)
        data_dir = home / ".local" / "share" / "app.hiddify.com" / "data"
        config_dir = home / ".config"
        data_dir.mkdir(parents=True)
        config_dir.mkdir(parents=True)

        cfg = data_dir / "current-config.json"
        cfg.write_text(
            json.dumps(
                {
                    "inbounds": [
                        {
                            "type": "mixed",
                            "tag": "mixed-in::1",
                            "listen": "::1",
                            "listen_port": 12334,
                        },
                        {
                            "type": "tproxy",
                            "tag": "tproxy-in::1",
                            "listen": "::1",
                            "listen_port": 12335,
                        },
                        {
                            "type": "mixed",
                            "tag": "mixed-in127.0.0.1",
                            "listen": "127.0.0.1",
                            "listen_port": 12334,
                        },
                    ]
                }
            )
        )

        kioslaverc = config_dir / "kioslaverc"
        kioslaverc.write_text(
            "\n".join(
                [
                    "[Proxy Settings]",
                    "httpProxy=http://[::1]:12334",
                    "httpsProxy=http://[::1]:12335",
                    "socksProxy=socks://[::1]:12336",
                    "ftpProxy=http://[::1]:12337",
                ]
            )
        )

        script.chmod(script.stat().st_mode | stat.S_IXUSR)
        proc = subprocess.run(
            [str(script)],
            cwd=REPO_ROOT,
            env={**os.environ, "HOME": str(home)},
            capture_output=True,
            text=True,
            check=False,
        )

        assert proc.returncode == 0, proc.stderr

        payload = json.loads(cfg.read_text())
        assert payload["inbounds"] == [
            {
                "type": "mixed",
                "tag": "mixed-in127.0.0.1",
                "listen": "127.0.0.1",
                "listen_port": 12334,
            }
        ]

        rewritten = kioslaverc.read_text()
        assert "[::1]" not in rewritten
        assert "127.0.0.1:12334" in rewritten
        assert "127.0.0.1:12335" in rewritten
        assert "127.0.0.1:12336" in rewritten
        assert "127.0.0.1:12337" in rewritten
