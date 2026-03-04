#!/usr/bin/env python3
"""Delete Salt log files older than the given number of days."""

import argparse
import time
from pathlib import Path


def prune_logs(log_dir: Path, max_age_days: int, dry_run: bool) -> list[tuple[Path, float]]:
    cutoff = time.time() - max_age_days * 86400
    removed = []
    for path in sorted(log_dir.glob("*.log")):
        try:
            mtime = path.stat().st_mtime
        except FileNotFoundError:
            continue
        if mtime < cutoff:
            removed.append((path, mtime))
            if not dry_run:
                try:
                    path.unlink()
                except FileNotFoundError:
                    pass
    return removed


def main() -> None:
    parser = argparse.ArgumentParser(description="Prune logs/ directory")
    parser.add_argument("--days", type=int, default=14, help="Retain logs newer than N days")
    parser.add_argument("--dry-run", action="store_true", help="List files but do not delete")
    args = parser.parse_args()

    log_dir = Path("logs")
    if not log_dir.is_dir():
        raise SystemExit(f"Log directory not found: {log_dir}")

    removed = prune_logs(log_dir, args.days, args.dry_run)
    action = "would remove" if args.dry_run else "removed"
    if removed:
        print(f"{action.capitalize()} {len(removed)} file(s):")
        for path, mtime in removed:
            formatted = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(mtime))
            print(f"  {path} (mtime {formatted})")
    else:
        print("No log files to prune")


if __name__ == "__main__":
    main()
