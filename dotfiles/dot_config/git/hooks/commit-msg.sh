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
# Require one or more [scope] blocks followed by a subject.
if ! [[ "$first_line" =~ '^\[[^][]+\]( \[[^][]+\])*[[:space:]][^[:space:]].*' ]]; then
  echo "Commit message must start with [scope] subject" >&2
  echo "Got: '$first_line'" >&2
  echo "Examples: [salt] decompose desktop includes, [docs] update hook guidance, [gui/quickshell] fix bar spacing" >&2
  exit 1
fi

subject="${first_line##*] }"
if [[ "$subject" == *"." ]]; then
  echo "Commit subject must not end with a period" >&2
  echo "Got: '$first_line'" >&2
  exit 1
fi

if [[ "$subject" =~ '^[[:space:]]*$' ]]; then
  echo "Commit subject must not be empty" >&2
  echo "Got: '$first_line'" >&2
  exit 1
fi

if [[ "$subject" =~ '^(Add|Adds|Added|Fix|Fixes|Fixed|Update|Updates|Updated|Remove|Removes|Removed|Refactor|Refactors|Refactored|Implement|Implements|Implemented)\b' ]]; then
  echo "Commit subject should use imperative mood in lowercase after the scope" >&2
  echo "Prefer: '${first_line/%$subject/}${subject,}'" >&2
  exit 1
fi

if [[ ! "$subject" =~ '^[[:lower:][:digit:]]' ]]; then
  echo "Commit subject should start with a lowercase imperative verb or identifier" >&2
  echo "Got: '$first_line'" >&2
  exit 1
fi

exit 0
