# NixOS Build Infrastructure Reference

Archived summary of `~/src/nixos-config/packages/` Nix-specific build infrastructure.
These directories were removed after migration to Salt; this doc preserves critical details.

## overlay.nix + overlays/

Entry point: `overlay.nix` loads `overlays/{functions,tools,media,dev,gui}.nix`,
merges everything into `pkgs.neg.*` namespace.

### Package fixes applied (may be relevant if issues recur on Fedora)

| Package | Fix | Reason |
|---------|-----|--------|
| keyutils | Local patch for format specifier | Upstream lore.kernel.org 403 |
| openldap | `doCheck = false` | Flaky syncreplication test |
| libyuv | `doCheck = false`, `UNIT_TEST=OFF` | OOM + warnings |
| rsync | `doCheck = false` | Hardlinks test failure |
| libuv | `doCheck = false` | Flaky tests |
| lua-language-server | `doCheck = false` | Flaky tests |
| pytest-xdist | `doCheck = false` | Flaky tests |
| hyprland-qtutils | Replace `Qt6::WaylandClientPrivate` → `Qt6::WaylandClient` | Build fix |
| bpftrace | Pin to LLVM 20 | Not yet LLVM 21 compatible |
| raysession | Patch `cgitb` import removal | Python 3.13 dropped cgitb |

### Custom packages defined in overlays

- `ncpamixer-wrapped` — ncpamixer with custom config file via `--add-flags "-c $config"`
- `python3-lto` — Python 3 with LTO + optimizations enabled
- `rsmetrx` — from flake input
- `fsread-nvim` — vim plugin from flake input
- `ncps` — from flake input

## overlays/functions.nix — Reusable helpers

```
overridePyScope(f)        — Override python3Packages scope
withOverrideAttrs(drv, f) — Shortcut for drv.overrideAttrs
overrideScopeFor(name, f) — Generic overrideScope for top-level sets
overrideRustCrates(drv, hash) — Set cargoHash for Rust packages
overrideGoModule(drv, hash)   — Set vendorHash for Go packages
withAutoreconf(drv)       — Add autoreconf toolchain to nativeBuildInputs
withCMakePolicyFloor(drv) — Enforce minimum CMake policy 3.5
```

## flake/

Glue layer exposing custom packages to home-manager: adguardian-term, hxtools,
pyprland, rmpc, surfingkeys-pkg, rofi-config, pipemixer, wiremix.

## lib/local-bin.nix

Home-manager helper: `name: text →` creates executable at `.local/bin/${name}`
with `force = true` (allows override).

## scripts/dev/profile-deploy.sh

NixOS deployment profiler:
1. Valgrind/Callgrind nix evaluation profiling → `callgrind.out`
2. GNU `time` on `just deploy` → real/user/sys CPU, max RSS
Output to timestamped `benchmarks/` directory.

## sqlitecpp/

SQLiteCpp 3.3.1 — C++ wrapper for SQLite3.
Source: `github.com/SRombauts/SQLiteCpp` (MIT).
Build: cmake + ninja, flags: `INTERNAL_SQLITE=ON`, `ENABLE_FTS5=ON`, tests/examples off.
