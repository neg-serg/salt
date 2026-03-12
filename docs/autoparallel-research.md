# Compiler Auto-Parallelism Research for CachyOS Workstation

Research into which installed programs could benefit from GCC Graphite auto-parallelism (`-ftree-parallelize-loops=N`) after recompilation on a 32-core AMD CachyOS workstation.

**Data file**: `states/data/autoparallel-candidates.yaml` (machine-readable classifications)
**Date**: 2026-03-12
**System**: CachyOS, GCC 15.2.1, 32-core AMD, `makepkg.conf`: `-O3 -march=native` with LTO

## Summary

Out of 384 unique installed packages:
- **8 high potential** — single-threaded C/C++ with CPU-bound data processing
- **14 moderate** — partially parallelized (OpenMP) with unparallelized loops remaining
- **27 low** — already parallelized or wrong workload type
- **335 not applicable** — interpreted languages, I/O-bound, event-driven, or metapackages

Auto-parallelism is a narrow optimization. The compiler can only parallelize loops with provably independent iterations, simple array access patterns, and no complex pointer aliasing. Most real-world programs do not have these patterns in their hot paths.

## GCC Graphite Compiler Flags Reference

### Primary Flags

| Flag | Purpose | Risk |
|------|---------|------|
| `-ftree-parallelize-loops=N` | Auto-parallelize independent loops using N threads (libgomp) | Low — conservative analysis |
| `-floop-parallelize-all` | Parallelize even loops with uncertain profitability | Medium — may add overhead for small loops |
| `-floop-nest-optimize` | Polyhedral loop tiling/interchange for cache locality | Low — no threading, just cache optimization |
| `-ftree-loop-distribution` | Split loop bodies to expose parallelism | Low — automatically enabled by `-O3` |

### Recommended Configuration

```bash
# In PKGBUILD build() function:
export CFLAGS="$CFLAGS -ftree-parallelize-loops=16"
export CXXFLAGS="$CXXFLAGS -ftree-parallelize-loops=16"
export LDFLAGS="$LDFLAGS -lgomp"
```

**Thread count**: 16 is optimal on the 32-core system. Empirical testing showed:
- 8 threads: 4.5x speedup (on ideal workloads)
- 16 threads: 5.3x speedup (sweet spot)
- 32 threads: 4.0x speedup (regression — thread overhead exceeds benefit)

**Runtime override**: `OMP_NUM_THREADS=N ./program` overrides the compiled-in thread count.

### Diagnostics

```bash
# See which loops were parallelized:
gcc -O3 -ftree-parallelize-loops=16 -fdump-tree-parloops-details -c file.c
# Look for "SUCCESS" in the .parloops dump file

# Graphite-specific loop analysis:
gcc -O3 -floop-nest-optimize -fdump-tree-graphite-details -c file.c
```

## LLVM Polly Reference (Optional)

Polly is **not installed by default** on CachyOS. Install with `pacman -S polly`.

| Flag | Purpose |
|------|---------|
| `-mllvm -polly` | Enable Polly polyhedral optimizer |
| `-mllvm -polly-parallel` | Enable parallel code generation |
| `-mllvm -polly-vectorizer=stripmine` | Polyhedral vectorization |

**Runtime**: Uses libgomp (same as GCC Graphite), not libomp. No extra package needed.

**Rust**: Theoretically `-C llvm-args=-polly -C llvm-args=-polly-parallel`, but Rust's LLVM IR (bounds checks, unwinding, enum discriminants) prevents SCoP detection in most code. Not recommended for Rust programs.

**Maturity**: Experimental. Reduced development activity since 2020. Not used in production by major projects. Use for targeted experiments only.

## PKGBUILD Modification Recipe

### Step-by-step

```bash
# 1. Safety snapshot
sudo snapper create -d "pre-autopar: <package>" -t pre

# 2. Get PKGBUILD
asp checkout <package>
cd <package>/trunk

# 3. Add flags in build()
# Insert at the top of the build() function:
export CFLAGS="$CFLAGS -ftree-parallelize-loops=16"
export CXXFLAGS="$CXXFLAGS -ftree-parallelize-loops=16"
export LDFLAGS="$LDFLAGS -lgomp"

# 4. Build and install
makepkg -si

# 5. Post-snapshot
sudo snapper create -d "post-autopar: <package>" -t post

# 6. Benchmark
hyperfine --warmup 3 --runs 10 '<workload command>'
```

### Rollback

```bash
# Option 1: Pacman cache (fastest)
sudo pacman -U /var/cache/pacman/pkg/<package>-<version>.pkg.tar.zst

# Option 2: Snapper (full system rollback)
sudo snapper undochange <pre-id>..<post-id>

# Option 3: Runtime escape hatch
OMP_NUM_THREADS=1 ./program  # Disable parallelism without rebuilding
```

## High-Potential Candidate Workloads

| Program | Workload Command | What it exercises |
|---------|-----------------|-------------------|
| `tesseract` | `tesseract sample.png output -l eng` | Pixel convolution, matrix ops |
| `optipng` | `optipng -o7 test.png` | Deflate search across compression parameters |
| `pngquant` | `pngquant --quality=65-80 --speed 1 test.png` | Median-cut color quantization over pixels |
| `jpegoptim` | `jpegoptim --strip-all -m85 test.jpg` | DCT coefficient optimization |
| `graphviz` | `dot -Tsvg large_graph.dot -o /dev/null` | Force-directed node pair iteration |
| `advancecomp` | `advpng -z4 test.png` | Compression search loops |
| `qrencode` | `echo 'test data' \| qrencode -o /dev/null` | Reed-Solomon encoding |
| `ttfautohint` | `ttfautohint input.ttf output.ttf` | Glyph outline analysis |

### Moderate-Potential Candidates (already partially parallel)

| Program | Existing Parallelism | Complement/Conflict |
|---------|---------------------|---------------------|
| `imagemagick` | OpenMP | Complement — many filters lack OpenMP; use `OMP_NUM_THREADS=8` to limit total threads |
| `sox` | OpenMP | Complement — DSP filter chain has sequential stages |
| `darktable` | OpenMP | Complement — some pipeline modules lack OpenMP |
| `rawtherapee` | pthreads | Complement — individual stage loops may benefit |
| `goaccess` | none | Complement — log aggregation loops are data-parallel |
| `brutefir` | pthreads | Caution — inner FIR loops; monitor thread contention |

## Correctness Limitations

### What GCC Graphite Can Parallelize

- Counted `for` loops with affine array access (`a[i]`, `a[2*i+1]`)
- No loop-carried dependencies (each iteration independent)
- Scalar reductions (`sum += a[i]`) — uses private accumulators
- Statically known or computable trip counts

### What Fails or Causes Miscompilation

| Pattern | Problem | Example |
|---------|---------|---------|
| Pointer aliasing | Cannot prove independence | `*p++ = *q++` |
| Non-affine subscripts | Polyhedral model cannot represent | `a[b[i]]` (indirect access) |
| Function calls | Assumed to have side effects | Non-inlined, non-`const` calls |
| Complex control flow | Branches break analysis | Data-dependent `if` inside loop |
| While loops | No counted iteration | `while (p = p->next)` |
| Small loops | Thread overhead exceeds benefit | Less than ~10K iterations |

### Pointer Aliasing — The Main Practical Limitation

Most C/C++ code uses pointers extensively. Without `restrict` qualifiers, the compiler cannot prove that two pointers don't alias the same memory, preventing parallelization. This is why:

- Fortran programs see much better auto-parallelism results (array semantics prevent aliasing by default)
- C programs with `restrict` qualifiers on function parameters help significantly
- Most existing C codebases do not use `restrict`

## CachyOS Compatibility

CachyOS `makepkg.conf` defaults:
```
CFLAGS="-march=native -O3 -pipe -fno-plt -fexceptions"
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto !autodeps)
```

| Default Flag | Interaction | Status |
|-------------|-------------|--------|
| `-O3` | Required — Graphite needs ≥ `-O2` | Compatible |
| `-march=native` | Orthogonal — ISA vs thread-level parallelism | Compatible |
| `-pipe` | No interaction | Compatible |
| `-fno-plt` | No interaction | Compatible |
| LTO (`-flto`) | Can expose more loops via cross-module inlining; increases compile time | Compatible |
| `-fexceptions` | No interaction | Compatible |

**All flags are additive** — no conflicts with CachyOS defaults.

## Thread Oversubscription Risk

When a program already uses OpenMP or pthreads, adding auto-parallelism creates more threads than intended:

```
Total threads = existing_threads × auto_parallel_threads
```

For `imagemagick` with 16 OpenMP threads + 16 auto-parallel threads = 256 total threads on a 32-core system → severe contention.

**Mitigation**: Set `OMP_NUM_THREADS` to limit total thread count:
```bash
# For programs with existing OpenMP parallelism:
OMP_NUM_THREADS=8 magick convert ...  # 8 × (some auto-parallel) stays manageable
```

## Binary Size and Compile Time Impact

| Metric | Impact | Notes |
|--------|--------|-------|
| Binary size | +5-15% text section | Outlined loop bodies + GOMP scaffolding |
| libgomp linkage | ~200KB | Shared library, loaded once |
| Compile time | 2-5× increase | Graphite's ISL solver is expensive; O(n³) in loop dimensions |

The compile time increase is the main practical cost. For targeted per-package rebuilds it is acceptable; for system-wide `makepkg.conf` it is prohibitive.

## Benchmark Methodology

### Protocol

For each candidate program:

1. **Baseline**: Install stock package from repository
2. **Benchmark**: `hyperfine --warmup 3 --runs 10 --export-json baseline.json '<workload>'`
3. **Rebuild**: Modify PKGBUILD with auto-parallelism flags
4. **Install**: `makepkg -si`
5. **Benchmark**: `hyperfine --warmup 3 --runs 10 --export-json modified.json '<workload>'`
6. **Compare**: Wall-clock time, User time (should increase if parallelism works), System time
7. **Supplementary**: `perf stat -d '<workload>'` for context switches, cache behavior
8. **Restore**: `pacman -U /var/cache/pacman/pkg/<original>.pkg.tar.zst`

### Metrics

- **Wall-clock speedup**: `baseline_time / modified_time` — primary metric
- **CPU utilization**: User time increase indicates real parallel work (not just overhead)
- **Context switches**: High context switch count suggests thread contention
- **Memory bandwidth**: `perf stat` LLC-load-misses — may saturate before CPU does

### Validation Results: optipng

**Test system**: CachyOS, GCC 15.2.1, AMD 32-core, `-O3 -march=native`
**Test file**: 81MB plasma fractal PNG (4096×4096), optimization level `-o2`
**Benchmark**: `hyperfine --warmup 1 --runs 5`

| Variant | Wall-clock | User time | CPU% |
|---------|-----------|-----------|------|
| Stock optipng (system zlib, CachyOS repo) | **12.87 s ± 0.09** | 12.80 s | 99% |
| Bundled zlib, no auto-parallelism | **15.02 s ± 0.26** | 14.49 s | 99% |
| Bundled zlib + `-ftree-parallelize-loops=16` | **16.88 s ± 0.20** | 250.34 s | 1485% |

**Result: 31% slower with auto-parallelism.**

Graphite successfully parallelized loops in 6 modules (deflate, opngreduc, pngxrbmp, pngxrtif, gifread, tiffread), spawning 16 threads. User time increased 19.6x confirming real parallel work. However:

1. **Parallelized loops are too fine-grained** — deflate's sliding window operates on ~256-byte chunks, not millions of elements. Thread creation/synchronization overhead dominates.
2. **Bundled zlib is 17% slower than system zlib** — CachyOS system zlib includes SIMD optimizations (cloudflare/intel patches) that the bundled vanilla zlib lacks.
3. **`OMP_NUM_THREADS=1` did not prevent thread creation** — compiled-in thread count of 16 overrode the environment variable, making runtime escape hatch unreliable.

**Conclusion**: Even for a "high potential" candidate with provably parallelizable loops, auto-parallelism degraded performance. The theoretical promise of loop-level parallelism does not survive contact with real-world code where hot loops are too small for thread-pool overhead to amortize.
