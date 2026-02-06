# Missing CLI Tools (Fedora Silverblue Migration)

Tools from nixos-config not yet available on the current Fedora system.
Fedora-repo tools are handled by `packages.sls`, custom RPMs by `build_rpms.sls` + `duf-rpm.sls`.

## Managed by Salt (packages.sls)

Already in Fedora repos, installed via `rpm-ostree install --idempotent`:
- **Dev:** ShellCheck, shfmt, strace, gdb, hyperfine, git-crypt, git-extras, diff-so-fancy, onefetch
- **CLI:** ugrep, aria2, jc, yq, glow, lowdown, moreutils, rlwrap, expect, dcfldd, prettyping, speedtest-cli, urlscan, abduco, cpufetch, sad, pastel, miller
- **Archives:** pigz, pbzip2, lbzip2, unar, unrar, patool
- **Media:** ffmpegthumbnailer, mediainfo, ImageMagick, jpegoptim, optipng, pngquant, advancecomp, darktable, rawtherapee, swayimg
- **Other:** borgbackup, jdupes, enca, streamlink

## Still need RPM build

### Rust (cargo build in Podman)
| Tool | Description | Source |
|------|-------------|--------|
| choose | Human-friendly cut | github.com/theryangeary/choose |
| ouch | Compress/decompress with auto-detection | github.com/ouch-org/ouch |
| htmlq | jq for HTML | github.com/mgdm/htmlq |
| erdtree | Modern tree with file sizes | github.com/solidiquis/erdtree |
| viu | Terminal image viewer | github.com/atanunq/viu |
| lutgen | LUT generator for color grading | github.com/ozwaldorf/lutgen-rs |
| fclones | Fast duplicate file finder | github.com/pkolaczk/fclones |
| grex | Regex generator from examples | github.com/pemistahl/grex |
| taplo | TOML toolkit/linter | github.com/tamasfe/taplo |
| kmon | Linux kernel module monitor | github.com/orhun/kmon |
| zfxtop | TUI system monitor | github.com/ssleert/zfxtop |

### Go
| Tool | Description | Source |
|------|-------------|--------|
| pup | HTML parser CLI | github.com/ericchiang/pup |
| scc | Fast code counter | github.com/boyter/scc |
| ctop | Container metrics TUI | github.com/bcicen/ctop |
| dive | Docker image layer explorer | github.com/wagoodman/dive |
| gist | GitHub gist CLI | github.com/defunkt/gist |

### Other
| Tool | Description | Source |
|------|-------------|--------|
| jujutsu (jj) | Git-compatible VCS | github.com/jj-vcs/jj (Rust) |
| git-filter-repo | Git history rewriting | github.com/newren/git-filter-repo (Python) |
| epr | Terminal EPUB reader | github.com/wustho/epr (Python) |
| zk | Zettelkasten note CLI | github.com/zk-org/zk (Go) |
| xxh | SSH with local shell config | github.com/xxh/xxh (Python) |
| nerdctl | containerd CLI | github.com/containerd/nerdctl (Go) |
| rapidgzip | Parallel gzip decompressor | github.com/mxmlnkn/rapidgzip (C++) |
| scour | SVG optimizer | github.com/scour-project/scour (Python, pip) |

## Summary

| Category | Count | Status |
|----------|-------|--------|
| Fedora repos (packages.sls) | ~40 | salt state ready |
| Custom RPMs (build_rpms.sls) | 6 | built + salt state ready |
| Need RPM build | ~23 | TODO |
