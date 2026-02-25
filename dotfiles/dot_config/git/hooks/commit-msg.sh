#!/usr/bin/env zsh
set -euo pipefail
f="$1"
read -r first_line < "$f"
first_line=${first_line//$'\r'/}
# Allowed exceptions
case "$first_line" in
  Merge\ * | Revert\ * | fixup!* | squash!* | WIP:* | WIP\ *)
    exit 0
    ;;
esac
# Require one or more [scope] blocks followed by a space
if [[ "$first_line" =~ '^\[[^][]+\]( \[[^][]+\])*[[:space:]]' ]]; then
  exit 0
fi
echo "Commit message must start with [scope] subject" >&2
echo "Got: '$first_line'" >&2
echo "Examples: [activation] ..., [docs] ..., [features] ..., [symlinks] ..." >&2
exit 1
