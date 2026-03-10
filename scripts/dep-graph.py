#!/usr/bin/env python3
"""Generate dependency graph of Salt states (include/require/watch/onchanges)."""

import argparse
import glob
import importlib.util
import os
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent

# Reuse index-salt.py rendering (same pattern as state-profiler.py)
_index_spec = importlib.util.spec_from_file_location(
    "index_salt_module", SCRIPTS_DIR / "index-salt.py"
)
if not _index_spec or not _index_spec.loader:
    raise ImportError("Cannot load index-salt.py")
_index_module = importlib.util.module_from_spec(_index_spec)
_index_spec.loader.exec_module(_index_module)


def collect_edges(state_results):
    """Extract include and requisite edges from rendered state results."""
    include_edges = []  # (from_file, to_file)
    requisite_edges = []  # (from_state, to_state, type)

    for rel, state_ids, includes, requisites, *_ in state_results:
        name = os.path.basename(rel).replace(".sls", "")
        # Include edges
        for inc in includes or []:
            include_edges.append((name, inc))
        # Requisite edges
        for req in requisites or []:
            if isinstance(req, dict):
                for req_type, targets in req.items():
                    if isinstance(targets, list):
                        for t in targets:
                            if isinstance(t, dict):
                                for mod, sid in t.items():
                                    label = f"{mod}:{sid}" if ":" in str(sid) else str(sid)
                                    requisite_edges.append((name, label, req_type))
                            elif isinstance(t, str):
                                requisite_edges.append((name, t, req_type))

    return include_edges, requisite_edges


def generate_dot(include_edges, requisite_edges, state_results):
    """Generate DOT format graph."""
    lines = ["digraph salt_states {"]
    lines.append("  rankdir=LR;")
    lines.append('  node [shape=box, style=filled, fillcolor="#e8e8e8", fontname="monospace"];')
    lines.append('  edge [fontname="monospace", fontsize=10];')
    lines.append("")

    # Collect all state file nodes
    nodes = set()
    for rel, *_ in state_results:
        name = os.path.basename(rel).replace(".sls", "")
        nodes.add(name)

    for node in sorted(nodes):
        lines.append(f'  "{node}";')

    lines.append("")

    # Include edges (solid black)
    for src, dst in include_edges:
        lines.append(f'  "{src}" -> "{dst}" [label="include", color="#333333"];')

    # Requisite edges (colored by type)
    colors = {
        "require": "#2196F3",  # blue
        "watch": "#FF9800",  # orange
        "onchanges": "#4CAF50",  # green
        "require_in": "#9C27B0",  # purple
    }
    for src, dst, req_type in requisite_edges:
        # Simplify dst to file name if it looks like a state reference
        color = colors.get(req_type, "#999999")
        lines.append(f'  "{src}" -> "{dst}" [label="{req_type}", color="{color}", style=dashed];')

    lines.append("}")
    return "\n".join(lines)


def generate_text_tree(include_edges, root="system_description"):
    """Generate text tree from include edges."""
    children = defaultdict(list)
    for src, dst in include_edges:
        children[src].append(dst)

    visited = set()
    lines = []

    def walk(node, prefix="", is_last=True):
        if node in visited:
            lines.append(f"{prefix}{'└── ' if is_last else '├── '}{node} (cycle)")
            return
        visited.add(node)
        connector = "└── " if is_last else "├── "
        lines.append(f"{prefix}{connector}{node}" if prefix else node)
        kids = sorted(children.get(node, []))
        for i, kid in enumerate(kids):
            extension = "    " if is_last else "│   "
            walk(kid, prefix + (extension if prefix else ""), i == len(kids) - 1)

    walk(root)
    return "\n".join(lines)


def detect_cycles(include_edges):
    """Detect cycles in include graph using DFS."""
    children = defaultdict(list)
    for src, dst in include_edges:
        children[src].append(dst)

    WHITE, GRAY, BLACK = 0, 1, 2
    color = defaultdict(int)
    cycles = []
    path = []

    def dfs(node):
        color[node] = GRAY
        path.append(node)
        for child in children[node]:
            if color[child] == GRAY:
                cycle_start = path.index(child)
                cycles.append(path[cycle_start:] + [child])
            elif color[child] == WHITE:
                dfs(child)
        path.pop()
        color[node] = BLACK

    for node in list(children.keys()):
        if color[node] == WHITE:
            dfs(node)

    return cycles


def main():
    parser = argparse.ArgumentParser(description="Generate Salt state dependency graph")
    parser.add_argument(
        "--format",
        choices=["dot", "svg", "text"],
        default="dot",
        help="Output format (default: dot)",
    )
    parser.add_argument(
        "--output", "-o", type=str, default=None, help="Output file (default: stdout)"
    )
    parser.add_argument(
        "--root",
        default="system_description",
        help="Root state for text tree (default: system_description)",
    )
    args = parser.parse_args()

    sls_files = sorted(glob.glob("states/*.sls"))
    if not sls_files:
        print("No .sls files found in states/", file=sys.stderr)
        sys.exit(2)

    state_results = _index_module.render_states(sls_files)
    include_edges, requisite_edges = collect_edges(state_results)

    # Check for cycles
    cycles = detect_cycles(include_edges)
    if cycles:
        print("WARNING: Circular dependencies detected:", file=sys.stderr)
        for cycle in cycles:
            print(f"  {' -> '.join(cycle)}", file=sys.stderr)
        if args.format != "text":
            pass  # Still generate graph but with exit code 1

    if args.format == "text":
        output = generate_text_tree(include_edges, args.root)
    else:
        dot_output = generate_dot(include_edges, requisite_edges, state_results)
        if args.format == "svg":
            try:
                result = subprocess.run(
                    ["dot", "-Tsvg"], input=dot_output, capture_output=True, text=True, check=True
                )
                output = result.stdout
            except FileNotFoundError:
                print("graphviz (dot) not found. Install: pacman -S graphviz", file=sys.stderr)
                sys.exit(2)
            except subprocess.CalledProcessError as e:
                print(f"dot failed: {e.stderr}", file=sys.stderr)
                sys.exit(2)
        else:
            output = dot_output

    if args.output:
        Path(args.output).write_text(output)
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(output)

    sys.exit(1 if cycles else 0)


if __name__ == "__main__":
    main()
