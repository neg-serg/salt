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

termcmd="${TERMCMD:-kitty}"

if [ "$save" = "1" ]; then
    startdir=$(dirname "$path")
    [ -d "$startdir" ] || startdir="$HOME"
    "$termcmd" -- sh -c "yazi '$startdir' --chooser-file='$out'"
    # If user selected a directory, append the suggested filename
    if [ -s "$out" ]; then
        selected=$(cat "$out")
        if [ -d "$selected" ]; then
            printf '%s/%s' "$selected" "$(basename "$path")" > "$out"
        fi
    fi
else
    "$termcmd" -- sh -c "yazi --chooser-file='$out'"
fi
