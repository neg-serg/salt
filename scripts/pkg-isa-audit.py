#!/usr/bin/env python3
"""
Scan installed ELF binaries for x86-64 ISA level and map to RPM packages.

Outputs JSON suitable for analysis of optimization potential.
Checks GNU property notes in ELF headers to determine what microarchitecture
level each binary was compiled for (v1=baseline, v2=SSE4.2, v3=AVX2, v4=AVX-512).

Usage:
    python3 scripts/pkg-isa-audit.py [--deep] > pkg-isa-audit.json

    --deep  Also scan for actual AVX/AVX-512 instruction usage via objdump
            (much slower, but shows real SIMD utilization)
"""

import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

SCAN_DIRS = ["/usr/bin", "/usr/sbin", "/usr/lib64", "/usr/lib", "/usr/libexec"]
ELF_MAGIC = b"\x7fELF"
ISA_RE = re.compile(r"x86-64-v(\d)")

# Instructions that indicate SIMD tier usage (for --deep mode)
SIMD_MARKERS = {
    "avx512": re.compile(
        r"\bv(?:padd|psub|pmul|pmadd|movdq|broadcast|perm)[a-z]*\s.*%[xyz]mm", re.I
    ),
    "avx2": re.compile(r"\bv(?:padd|psub|pmul|pmadd|movdq|broadcast|perm)[a-z]*\s.*%ymm", re.I),
    "avx": re.compile(r"\bv(?:add|sub|mul|div|mov|broadcast)[a-z]*\s.*%[xy]mm", re.I),
    "sse4": re.compile(r"\b(?:pblendvb|blendvp|roundp|rounds|pmuldq|pcmpeqq)\b", re.I),
}


def is_elf(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) == ELF_MAGIC
    except (OSError, PermissionError):
        return False


def find_elf_files():
    """Find all ELF files in system directories."""
    elfs = []
    for d in SCAN_DIRS:
        p = Path(d)
        if not p.exists():
            continue
        for f in p.rglob("*"):
            if f.is_file() and not f.is_symlink() and is_elf(f):
                elfs.append(str(f))
    return elfs


def get_isa_level(filepath):
    """Extract x86-64 ISA level from ELF GNU property notes."""
    try:
        r = subprocess.run(
            ["readelf", "-n", filepath],
            capture_output=True,
            text=True,
            timeout=10,
        )
        levels = ISA_RE.findall(r.stdout)
        if levels:
            return max(int(v) for v in levels)
    except (subprocess.TimeoutExpired, OSError):
        pass
    return 1  # no marker = baseline v1


def get_file_type(filepath):
    """Get ELF binary type (executable vs shared library)."""
    try:
        r = subprocess.run(
            ["file", "-b", filepath],
            capture_output=True,
            text=True,
            timeout=5,
        )
        out = r.stdout
        if "shared object" in out or ".so" in filepath:
            return "shared_lib"
        if "executable" in out or "ELF" in out:
            return "executable"
    except (subprocess.TimeoutExpired, OSError):
        pass
    return "unknown"


def scan_simd_usage(filepath):
    """Deep scan: check what SIMD instructions a binary actually uses."""
    tiers = set()
    try:
        r = subprocess.run(
            ["objdump", "-d", "--no-show-raw-insn", filepath],
            capture_output=True,
            text=True,
            timeout=60,
        )
        text = r.stdout
        for tier, pattern in SIMD_MARKERS.items():
            if pattern.search(text):
                tiers.add(tier)
    except (subprocess.TimeoutExpired, OSError):
        pass
    return sorted(tiers)


def batch_rpm_query(filepaths):
    """Map files to RPM packages in batches."""
    file_to_pkg = {}
    batch_size = 200
    for i in range(0, len(filepaths), batch_size):
        batch = filepaths[i : i + batch_size]
        try:
            r = subprocess.run(
                ["rpm", "-qf", "--queryformat", "%{NAME}\\t%{VERSION}-%{RELEASE}\\t%{ARCH}\\n"]
                + batch,
                capture_output=True,
                text=True,
                timeout=30,
            )
            lines = r.stdout.strip().split("\n")
            idx = 0
            for line in lines:
                if idx >= len(batch):
                    break
                parts = line.split("\t")
                if len(parts) == 3 and "not owned" not in line:
                    file_to_pkg[batch[idx]] = {
                        "name": parts[0],
                        "evr": parts[1],
                        "arch": parts[2],
                    }
                idx += 1
        except (subprocess.TimeoutExpired, OSError):
            pass
    return file_to_pkg


def classify_package(name, files):
    """Heuristic: guess the language/toolchain from binary characteristics."""
    for f in files:
        if f.endswith(".so") or ".so." in f:
            continue
        # Check for Go signature (large static binaries)
        try:
            size = os.path.getsize(f)
            if size > 5_000_000:  # Go binaries are typically large
                r = subprocess.run(
                    ["readelf", "-p", ".comment", f],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if "Go " in r.stdout or "go." in r.stdout:
                    return "go"
                # Also check for Go sections
                r2 = subprocess.run(
                    ["readelf", "-S", f],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if ".gopclntab" in r2.stdout or ".go.buildinfo" in r2.stdout:
                    return "go"
        except (OSError, subprocess.TimeoutExpired):
            pass

        # Check .comment for compiler
        try:
            r = subprocess.run(
                ["readelf", "-p", ".comment", f],
                capture_output=True,
                text=True,
                timeout=5,
            )
            comment = r.stdout.lower()
            if "rustc" in comment:
                return "rust"
            if "gcc" in comment:
                return "c/c++"
            if "clang" in comment:
                return "c/c++(clang)"
        except (OSError, subprocess.TimeoutExpired):
            pass

    return "unknown"


def main():
    deep = "--deep" in sys.argv

    print("Scanning for ELF binaries...", file=sys.stderr)
    elf_files = find_elf_files()
    print(f"Found {len(elf_files)} ELF files", file=sys.stderr)

    # Check ISA levels in parallel
    print("Checking ISA levels...", file=sys.stderr)
    file_isa = {}
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        futures = {pool.submit(get_isa_level, f): f for f in elf_files}
        for fut in as_completed(futures):
            f = futures[fut]
            file_isa[f] = fut.result()

    # Map to packages
    print("Mapping to RPM packages...", file=sys.stderr)
    file_to_pkg = batch_rpm_query(elf_files)

    # Aggregate per package
    packages = defaultdict(
        lambda: {
            "files": [],
            "isa_levels": [],
            "evr": "",
            "arch": "",
        }
    )

    for f in elf_files:
        pkg_info = file_to_pkg.get(f)
        if not pkg_info:
            continue
        name = pkg_info["name"]
        packages[name]["evr"] = pkg_info["evr"]
        packages[name]["arch"] = pkg_info["arch"]
        entry = {
            "path": f,
            "isa": f"v{file_isa.get(f, 1)}",
            "type": get_file_type(f),
        }

        if deep:
            entry["simd_used"] = scan_simd_usage(f)

        packages[name]["files"].append(entry)
        packages[name]["isa_levels"].append(file_isa.get(f, 1))

    # Build output
    print("Classifying packages...", file=sys.stderr)
    output = []
    for name, data in sorted(packages.items()):
        levels = data["isa_levels"]
        max_isa = max(levels) if levels else 1
        min_isa = min(levels) if levels else 1

        # Only classify a sample of packages (slow operation)
        toolchain = classify_package(name, [e["path"] for e in data["files"][:3]])

        pkg = {
            "package": name,
            "version": data["evr"],
            "arch": data["arch"],
            "toolchain": toolchain,
            "elf_count": len(data["files"]),
            "current_isa": f"v{max_isa}",
            "min_isa_in_pkg": f"v{min_isa}",
            "potential_gain": max_isa < 4,
            "files": data["files"],
        }
        output.append(pkg)

    # Summary stats
    summary = {
        "total_packages": len(output),
        "total_elf_files": len(elf_files),
        "by_isa": {
            f"v{v}": sum(1 for p in output if p["current_isa"] == f"v{v}") for v in [1, 2, 3, 4]
        },
        "by_toolchain": {},
        "upgradeable_to_v4": sum(1 for p in output if p["potential_gain"]),
    }
    toolchains = set(p["toolchain"] for p in output)
    for tc in sorted(toolchains):
        summary["by_toolchain"][tc] = sum(1 for p in output if p["toolchain"] == tc)

    result = {
        "meta": {
            "description": "x86-64 ISA level audit of installed RPM packages",
            "host": os.uname().nodename,
            "deep_scan": deep,
            "isa_levels": {
                "v1": "baseline x86-64 (SSE2)",
                "v2": "+SSE4.2, POPCNT, CMPXCHG16B",
                "v3": "+AVX2, BMI1/2, FMA (CachyOS default)",
                "v4": "+AVX-512F/VL/BW/CD/DQ (Zen 4+, some Xeon)",
            },
        },
        "summary": summary,
        "packages": output,
    }

    json.dump(result, sys.stdout, indent=2)
    print(file=sys.stdout)  # trailing newline

    print(
        f"\nDone. {summary['total_packages']} packages, "
        f"{summary['total_elf_files']} ELF files scanned.",
        file=sys.stderr,
    )
    print(f"ISA distribution: {summary['by_isa']}", file=sys.stderr)
    print(f"Upgradeable to v4: {summary['upgradeable_to_v4']}", file=sys.stderr)


if __name__ == "__main__":
    main()
