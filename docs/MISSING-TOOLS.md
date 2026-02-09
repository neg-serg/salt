# Missing CLI Tools (Fedora Silverblue Migration)

Tools from nixos-config not yet available on the current Fedora system.
Fedora-repo tools are handled by `packages.sls`, custom RPMs by `build_rpms.sls` + `install_rpms.sls`.

## Managed by Salt (packages.sls)

Already in Fedora repos, installed via `rpm-ostree install --idempotent`:
- **Dev:** ShellCheck, shfmt, strace, gdb, hyperfine, git-crypt, git-extras, diff-so-fancy, onefetch
- **CLI:** ugrep, aria2, jc, yq, glow, lowdown, moreutils, rlwrap, expect, dcfldd, prettyping, speedtest-cli, urlscan, abduco, cpufetch, sad, pastel, miller
- **Archives:** pigz, pbzip2, lbzip2, unar, unrar, patool
- **Media:** ffmpegthumbnailer, mediainfo, ImageMagick, jpegoptim, optipng, pngquant, advancecomp, darktable, rawtherapee, swayimg
- **Other:** borgbackup, jdupes, enca, streamlink

## Custom RPMs (built)

### Rust
choose, ouch, htmlq, erdtree, viu, fclones, grex, kmon, raise, jujutsu (jj), lutgen, taplo

### Go
duf, massren, pup, scc, ctop, dive, zfxtop, zk, nerdctl

### Other
pipemixer (C), epr (Python), git-filter-repo (Python), richcolors (Python), neg-pretty-printer (Python), xxh (Python), scour (Python), rapidgzip (Python/C++), gist (Ruby), iosevka-neg-fonts (font)

## Summary

| Category | Count | Status |
|----------|-------|--------|
| Fedora repos (packages.sls) | ~40 | salt state ready |
| Custom RPMs (build_rpms.sls) | 31 | built + salt state ready |
