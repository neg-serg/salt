#!/usr/bin/env python3
"""Parse salt-apply logs and print the slowest states with include context."""

import argparse
import glob
import importlib.util
import json
import os
import re
import sys
from collections import deque
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Profile Salt state durations from logs")
    parser.add_argument("log", type=Path, help="Path to salt-apply log file")
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
    args = parser.parse_args()

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
