#!/bin/bash
cli_packages=("salt" "ripgrep" "tig" "zsh" "tree-sitter-cli" "xsel" "yt-dlp" "git" "git-delta" "fd-find" "zoxide" "ncdu" "fastfetch" "aria2" "p7zip" "unzip" "zip" "xz" "lsof" "procps-ng" "psmisc" "pv" "parallel" "perl-Image-ExifTool" "chafa" "convmv" "dos2unix" "moreutils" "duf" "rmlint" "stow" "du-dust" "pwgen" "par" "entr" "inotify-tools" "progress" "reptyr" "goaccess" "lnav" "qrencode" "asciinema" "sox" "zbar" "libnotify")

to_install=()
layered=$(rpm-ostree status --json | jq -r '.deployments[]."requested-packages"[]?' | sort -u)
for pkg in "${cli_packages[@]}"; do
  if ! rpm -q "$pkg" &>/dev/null && ! echo "$layered" | grep -Fqx "$pkg"; then
    to_install+=("$pkg")
  fi
done

echo "To install: ${to_install[*]}"
