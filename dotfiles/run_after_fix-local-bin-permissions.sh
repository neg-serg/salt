#!/bin/sh
for f in ~/.local/bin/*; do
    [ -e "$f" ] && [ ! -L "$f" ] && chmod +x "$f"
done
