# salt-formatter.awk — live progress formatter for salt-call output
# Usage: tail -f logfile | awk -v maxlen=100 -f salt-formatter.awk
#
# Displays: spinner with current state, colored result marks (✓/✦/✗),
# durations, and summary. Critical errors are highlighted in red.

# Catch critical errors (SLS rendering failures, import errors, etc.)
/\[CRITICAL\]/ {
    msg = $0
    sub(/.*\[CRITICAL\]\[[0-9]+\] /, "", msg)
    printf "\r\033[K\033[31m✗ %s\033[0m\n", msg; fflush()
    errors++
    next
}

# Catch error lines from state output (e.g. "    - Rendering SLS ... failed:")
/^[[:space:]]+- .*[Ff]ailed:/ {
    msg = $0
    sub(/^[[:space:]]+- /, "", msg)
    printf "\033[31m  ✗ %s\033[0m\n", msg; fflush()
    errors++
    next
}

# Show current state being executed (overwritten in-place)
match($0, /Executing state ([^ ]+) for \[([^]]+)\]/, m) {
    state_n++
    line = "▶ [" state_n "] " m[1] " " m[2]
    if (length(line) > maxlen) line = substr(line, 1, maxlen) "…"
    printf "\r\033[K%s", line; fflush()
}

# Clear line when salt-call prints "local:" header
/^local:/ { printf "\r\033[K"; fflush() }

# Result line: Name/Function/Result/Duration — print colored mark
match($0, /^  Name: ([^ ]+) - Function: ([^ ]+) - Result: ([^ ]+) - Started: [^ ]+ - Duration: ([0-9.]+ ms)/, m) {
    dur = " (" m[4] ")"
    if (m[3] == "Changed") mark = "\033[33m✦\033[0m"
    else if (m[3] ~ /^Fail/) mark = "\033[31m✗\033[0m"
    else mark = "✓"
    printf "%s%s\n", mark " " m[1], dur; fflush()
}

# Summary block at the end
/^Summary for / { in_summary=1 }
in_summary && /^[-]+$/ { print; fflush() }
in_summary && /^(Succeeded|Failed|Total)/ { print; fflush() }
