#!/usr/bin/env python3
"""Parse salt-apply logs and print the slowest states with include context."""

import argparse
import glob
import importlib.util
import json
import os
import re
import statistics
import sys
from collections import defaultdict, deque
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
_index_spec = importlib.util.spec_from_file_location(
    "index_salt_module", SCRIPTS_DIR / "index-salt.py"
)
if not _index_spec or not _index_spec.loader:  # pragma: no cover - defensive
    raise ImportError("Cannot load index-salt.py")
_index_module = importlib.util.module_from_spec(_index_spec)
_index_spec.loader.exec_module(_index_module)  # type: ignore[attr-defined]

SALT_DIRECTIVES = {"include", "extend"}


NAME_RE = re.compile(r"Name:\s+(.*?)\s+- Function:.*- Duration:\s+(.+)$")
_DURATION_PART_RE = re.compile(r"([0-9.]+)\s*(ms|min|s|h)")


def _parse_duration_expr(expr: str) -> float:
    total = 0.0
    for match in _DURATION_PART_RE.finditer(expr):
        value = float(match.group(1))
        unit = match.group(2)
        if unit == "ms":
            total += value
        elif unit == "s":
            total += value * 1000
        elif unit == "min":
            total += value * 60_000
        elif unit == "h":
            total += value * 3_600_000
    return total


def parse_log(path: Path) -> list[tuple[float, str]]:
    durations: list[tuple[float, str]] = []
    with path.open() as fh:
        for raw in fh:
            match = NAME_RE.search(raw)
            if not match:
                continue
            state_id = match.group(1).strip()
            duration_expr = match.group(2).strip()
            duration = _parse_duration_expr(duration_expr)
            durations.append((duration, state_id))
    return durations


def build_state_metadata(root_state: str):
    sls_files = sorted(glob.glob("states/*.sls"))
    file_data = []
    for path in sls_files:
        with open(path) as fh:
            content = fh.read()
        file_data.append((os.path.basename(path).replace(".sls", ""), content))
    state_results = _index_module.render_states(sls_files)
    graph, _, _ = _index_module.build_state_graph(state_results)
    state_files = {}
    for rel, state_ids, _, _, _ in state_results:
        name = os.path.basename(rel).replace(".sls", "")
        for sid in state_ids:
            state_files[sid] = name
    include_paths = build_include_paths(graph, root_state)
    text_map = build_text_state_map(file_data)
    return state_files, include_paths, text_map, dict(file_data)


def build_text_state_map(file_data):
    mapping = {}
    pattern = re.compile(r"^([A-Za-z0-9_.:-]+):", re.MULTILINE)
    for name, content in file_data:
        for match in pattern.finditer(content):
            state_id = match.group(1).strip()
            if not state_id or state_id in SALT_DIRECTIVES:
                continue
            mapping.setdefault(state_id, name)
    return mapping


def build_include_paths(graph, root_state):
    paths = {}
    if root_state not in graph:
        return paths
    queue = deque([(root_state, [root_state])])
    while queue:
        node, path = queue.popleft()
        if node in paths:
            continue
        paths[node] = path
        for child in graph.get(node, []):
            queue.append((child, path + [child]))
    return paths


def format_context(state_id: str, state_files, include_paths, text_map, file_contents):
    state_file = (
        state_files.get(state_id)
        or text_map.get(state_id)
        or find_state_via_substring(state_id, file_contents)
    )
    if state_file:
        chain = include_paths.get(state_file)
        if chain:
            return " → ".join(chain + [state_id]), chain + [state_id], state_file
        return f"{state_file} → {state_id}", [state_file, state_id], state_file
    return state_id, [state_id], None


def find_state_via_substring(state_id: str, file_contents):
    if not state_id:
        return None
    pattern = re.compile(rf"\b{re.escape(state_id)}\b")
    for name, content in file_contents.items():
        if pattern.search(content):
            return name
    return None


def run_trend(json_mode: bool) -> None:
    """Scan all logs/*.log files, aggregate durations by state_id, output ranked stats."""
    logs_dir = Path("logs")
    if not logs_dir.is_dir():
        raise SystemExit("No logs/ directory found")
    log_files = sorted(logs_dir.glob("*.log"), key=lambda p: p.stat().st_mtime)
    if not log_files:
        raise SystemExit("No .log files found in logs/")

    by_state: dict[str, list[float]] = defaultdict(list)
    latest_by_state: dict[str, float] = {}

    for log_path in log_files:
        durations = parse_log(log_path)
        for dur, state_id in durations:
            by_state[state_id].append(dur)
            latest_by_state[state_id] = dur

    rows = []
    for state_id, durs in by_state.items():
        rows.append(
            {
                "state_id": state_id,
                "count": len(durs),
                "min_ms": round(min(durs), 2),
                "avg_ms": round(statistics.mean(durs), 2),
                "max_ms": round(max(durs), 2),
                "latest_ms": round(latest_by_state[state_id], 2),
            }
        )
    rows.sort(key=lambda r: r["avg_ms"], reverse=True)

    if json_mode:
        json.dump(rows, fp=sys.stdout, indent=2)
        print()
        return

    cols = [f"{'state_id':<60s}", f"{'count':>5s}", f"{'min_ms':>10s}"]
    cols += [f"{'avg_ms':>10s}", f"{'max_ms':>10s}", f"{'latest_ms':>10s}"]
    hdr = " ".join(cols)
    print(f"Trend across {len(log_files)} log file(s):")
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        print(
            f"{r['state_id']:<60s} {r['count']:>5d} {r['min_ms']:>10.2f} "
            f"{r['avg_ms']:>10.2f} {r['max_ms']:>10.2f} {r['latest_ms']:>10.2f}"
        )


def run_compare(log1: Path, log2: Path, json_mode: bool) -> None:
    """Compare two log files and highlight regressions (>20% slower)."""
    if not log1.is_file():
        raise SystemExit(f"Log file not found: {log1}")
    if not log2.is_file():
        raise SystemExit(f"Log file not found: {log2}")

    def _to_dict(durations: list[tuple[float, str]]) -> dict[str, float]:
        d: dict[str, float] = {}
        for dur, state_id in durations:
            d[state_id] = dur  # last occurrence wins
        return d

    d1 = _to_dict(parse_log(log1))
    d2 = _to_dict(parse_log(log2))

    common = set(d1) & set(d2)
    rows = []
    for state_id in common:
        v1, v2 = d1[state_id], d2[state_id]
        delta = v2 - v1
        pct = (delta / v1 * 100) if v1 != 0 else float("inf") if delta > 0 else 0.0
        regression = pct > 20
        rows.append(
            {
                "state_id": state_id,
                "log1_ms": round(v1, 2),
                "log2_ms": round(v2, 2),
                "delta_ms": round(delta, 2),
                "change_pct": round(pct, 2),
                "regression": regression,
            }
        )
    rows.sort(key=lambda r: abs(r["delta_ms"]), reverse=True)

    if json_mode:
        json.dump(rows, fp=sys.stdout, indent=2)
        print()
        return

    hdr = f"{'state_id':<60s} {'log1_ms':>10s} {'log2_ms':>10s} {'delta_ms':>10s} {'change%':>8s}  "
    print(f"Comparison: {log1} vs {log2}")
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        marker = "\u26a0" if r["regression"] else " "
        print(
            f"{r['state_id']:<60s} {r['log1_ms']:>10.2f} {r['log2_ms']:>10.2f} "
            f"{r['delta_ms']:>10.2f} {r['change_pct']:>7.1f}% {marker}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Profile Salt state durations from logs")
    parser.add_argument("log", nargs="?", type=Path, help="Path to salt-apply log file")
    parser.add_argument("--top", type=int, default=10, help="Number of slowest states to show")
    parser.add_argument(
        "--min-ms", type=float, default=0.0, help="Only show durations >= this threshold"
    )
    parser.add_argument(
        "--json", action="store_true", help="Output JSON instead of human-readable table"
    )
    parser.add_argument(
        "--root-state",
        default="system_description",
        help="Top-level state used to compute include chains",
    )
    parser.add_argument(
        "--trend",
        action="store_true",
        help="Scan all logs/*.log files and show per-state duration statistics",
    )
    parser.add_argument(
        "--compare",
        nargs=2,
        type=Path,
        metavar=("LOG1", "LOG2"),
        help="Compare two log files and highlight regressions",
    )
    args = parser.parse_args()

    if args.trend:
        run_trend(json_mode=args.json)
        return

    if args.compare:
        run_compare(args.compare[0], args.compare[1], json_mode=args.json)
        return

    if args.log is None:
        parser.error("the following arguments are required: log")

    if not args.log.is_file():
        raise SystemExit(f"Log file not found: {args.log}")

    durations = [item for item in parse_log(args.log) if item[0] >= args.min_ms]
    durations.sort(reverse=True)
    top = durations[: args.top]

    state_files, include_paths, text_map, file_contents = build_state_metadata(args.root_state)

    if args.json:
        payload = []
        for duration, state_id in top:
            _, path_list, state_file = format_context(
                state_id, state_files, include_paths, text_map, file_contents
            )
            payload.append(
                {
                    "state": state_id,
                    "duration_ms": duration,
                    "file": state_file,
                    "include_path": path_list,
                }
            )
        json.dump(payload, fp=sys.stdout, indent=2)
        print()
        return

    print(f"Top {len(top)} slowest states in {args.log}:")
    for duration, state_id in top:
        context, _, _ = format_context(
            state_id, state_files, include_paths, text_map, file_contents
        )
        print(f"  {duration:8.2f} ms  {context}")


if __name__ == "__main__":
    main()
