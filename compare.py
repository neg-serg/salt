cli_packages = [
    'salt', 'ripgrep', 'tig', 'zsh', 'tree-sitter-cli', 'xsel', 'yt-dlp',
    'git', 'git-delta', 'fd-find', 'zoxide', 'ncdu', 'fastfetch',
    'aria2', 'p7zip', 'unzip', 'zip', 'xz', 'lsof', 'procps-ng',
    'psmisc', 'pv', 'parallel', 'perl-Image-ExifTool', 'chafa', 'convmv',
    'dos2unix', 'moreutils', 'duf', 'rmlint', 'stow', 'massren',
    'du-dust', 'pwgen', 'par', 'entr', 'inotify-tools', 'progress',
    'reptyr', 'goaccess', 'lnav', 'qrencode', 'asciinema', 'sox', 'zbar',
    'libnotify'
]
import subprocess
import json

status = json.loads(subprocess.check_output(['rpm-ostree', 'status', '--json']))
requested = set()
for dep in status['deployments']:
    requested.update(dep.get('requested-packages', []))

print("Missing from requested:")
for pkg in cli_packages:
    if pkg not in requested:
        print(f"  {pkg}")

print("\nExtra in requested (not in cli_packages):")
for pkg in requested:
    if pkg not in cli_packages:
        print(f"  {pkg}")
