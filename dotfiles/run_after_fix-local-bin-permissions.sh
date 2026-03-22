#!/bin/sh
for f in ~/.local/bin/*; do
    [ -e "$f" ] && chmod +x "$f"
done
