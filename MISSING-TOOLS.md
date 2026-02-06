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
choose, ouch, htmlq, erdtree, viu, fclones, grex, kmon, raise, jujutsu (jj)

### Go
duf, massren, pup, scc, ctop, dive, zfxtop, zk

### Other
pipemixer (C), epr (Python), git-filter-repo (Python), richcolors (Python), neg-pretty-printer (Python), iosevka-neg-fonts (font)

## Still need RPM build

| Tool | Description | Source |
|------|-------------|--------|
| lutgen | LUT generator for color grading | github.com/ozwaldorf/lutgen-rs (Rust) |
| taplo | TOML toolkit/linter | github.com/tamasfe/taplo (Rust) |
| gist | GitHub gist CLI | github.com/defunkt/gist (Ruby) |
| xxh | SSH with local shell config | github.com/xxh/xxh (Python) |
| nerdctl | containerd CLI | github.com/containerd/nerdctl (Go) |
| rapidgzip | Parallel gzip decompressor | github.com/mxmlnkn/rapidgzip (C++) |
| scour | SVG optimizer | github.com/scour-project/scour (Python) |

## Summary

| Category | Count | Status |
|----------|-------|--------|
| Fedora repos (packages.sls) | ~40 | salt state ready |
| Custom RPMs (build_rpms.sls) | 24 | built + salt state ready |
| Need RPM build | 7 | TODO |
