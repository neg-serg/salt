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

# Portal environment has minimal PATH — ensure user binaries are reachable
export PATH="$HOME/.local/bin:$PATH"

termcmd="${TERMCMD:-kitty}"

if [ "$save" = "1" ]; then
    startdir=$(dirname "$path")
    [ -d "$startdir" ] || startdir="$HOME"
    suggested=$(basename "$path")

    # Write inner script to a temp file to avoid quoting hell
    tmp=$(mktemp /tmp/yazi-chooser-XXXXXX.sh)
    cat > "$tmp" << 'INNER'
#!/bin/sh
yazi "$YAZI_STARTDIR" --chooser-file="$YAZI_OUT"
if [ -s "$YAZI_OUT" ]; then
    selected=$(cat "$YAZI_OUT")
    if [ -d "$selected" ]; then
        clipboard=$(wl-paste --no-newline 2>/dev/null | head -1)
        default="${clipboard:-$YAZI_SUGGESTED}"
        printf '\nSave as [%s]: ' "$default"
        read -r fname
        fname="${fname:-$default}"
        printf '%s/%s' "$selected" "$fname" > "$YAZI_OUT"
    fi
fi
INNER
    chmod +x "$tmp"

    export YAZI_STARTDIR="$startdir"
    export YAZI_OUT="$out"
    export YAZI_SUGGESTED="$suggested"
    "$termcmd" -- sh "$tmp"
    rm -f "$tmp"
else
    "$termcmd" -- sh -c "yazi --chooser-file='$out'"
fi
