#!/bin/sh
# xdg-desktop-portal-termfilechooser wrapper for yazi
#
# Args: multiple directory save path out
#   1. "1" if multiple files can be chosen, "0" otherwise.
#   2. "1" if a directory should be chosen, "0" otherwise.
#   3. "0" if opening, "1" if saving (writing to a file).
#   4. Suggested save path (only relevant when save=1).
#   5. Output file to write selected path(s) to, one per line.

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"

# Portal environment has minimal PATH, so ensure user binaries are reachable.
export PATH="$HOME/.local/bin:$PATH"

# Debug: YAZI_CHOOSER_DEBUG=1 to log portal args to /tmp/yazi-chooser.log
if [ "${YAZI_CHOOSER_DEBUG:-0}" = "1" ]; then
    printf '%s args: multiple=%s directory=%s save=%s path=%s out=%s suggested=%s\n' \
        "$(date -Iseconds)" "$1" "$2" "$3" "$4" "$5" \
        "$(basename "$4" 2>/dev/null)" >> /tmp/yazi-chooser.log
fi

termcmd="${TERMCMD:-kitty}"

if [ "$save" = "1" ]; then
    startdir=$(dirname "$path")
    [ -d "$startdir" ] || startdir="$HOME"
    suggested=$(basename "$path")

    tmp=$(mktemp /tmp/yazi-chooser-XXXXXX.sh)
    cat > "$tmp" << 'INNER'
#!/bin/bash
printf '\033[1mSave file:\033[0m %s\n' "$YAZI_SUGGESTED"
printf 'Pick a directory in yazi, then confirm the filename.\n\n'
yazi "$YAZI_STARTDIR" --chooser-file="$YAZI_OUT"
if [ -s "$YAZI_OUT" ]; then
    selected=$(cat "$YAZI_OUT")
    if [ ! -d "$selected" ]; then
        selected=$(dirname "$selected")
    fi
    default="$YAZI_SUGGESTED"
    if [ -z "$default" ]; then
        default=$(wl-paste --no-newline 2>/dev/null | head -1)
    fi
    read -e -i "$default" -p $'\nSave as: ' fname
    if [ -z "$fname" ]; then
        > "$YAZI_OUT"
    else
        printf '%s/%s' "$selected" "$fname" > "$YAZI_OUT"
    fi
    if [ "${YAZI_CHOOSER_DEBUG:-0}" = "1" ]; then
        printf '%s resolved_path=%s\n' \
            "$(date -Iseconds)" "$(cat "$YAZI_OUT")" >> /tmp/yazi-chooser.log
    fi
fi
INNER
    chmod +x "$tmp"

    export YAZI_STARTDIR="$startdir"
    export YAZI_OUT="$out"
    export YAZI_SUGGESTED="$suggested"
    export YAZI_CHOOSER_DEBUG="${YAZI_CHOOSER_DEBUG:-0}"
    "$termcmd" --class yazi-chooser -- bash "$tmp"
    rm -f "$tmp"
else
    "$termcmd" --class yazi-chooser -- sh -c "yazi --chooser-file='$out'"
fi
