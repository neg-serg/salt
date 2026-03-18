#!/usr/bin/env zsh
# Boot benchmark: captures systemd-analyze output for before/after comparison.
# Usage: boot-benchmark.sh [--label NAME]

set -euo pipefail

local label=""
local log_dir="${0:a:h:h}/logs/boot"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label="$2"; shift 2 ;;
    --help|-h)
      print "Usage: ${0:t} [--label NAME]"
      print "Captures boot timing to logs/boot/ directory."
      exit 0 ;;
    *) print "Unknown option: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$log_dir"

local ts=$(date +%Y%m%d-%H%M%S)
local suffix="${label:+-${label}}"
local logfile="${log_dir}/boot-${ts}${suffix}.log"

{
  print "=== Boot Benchmark ==="
  print "Date: $(date -Iseconds)"
  print "Label: ${label:-<none>}"
  print "Host: $(hostname)"
  print ""

  print "=== systemd-analyze ==="
  systemd-analyze 2>&1
  print ""

  print "=== systemd-analyze blame (top 20) ==="
  systemd-analyze blame 2>&1 | grep -v 'dev-disk\|dev-nvme\|sys-devices' | head -20
  print ""

  print "=== systemd-analyze critical-chain ==="
  systemd-analyze critical-chain 2>&1
  print ""

  print "=== systemd-analyze blame --user (top 10) ==="
  systemd-analyze blame --user 2>&1 | head -10
  print ""

  print "=== systemd-analyze critical-chain --user ==="
  systemd-analyze critical-chain --user 2>&1
} > "$logfile" 2>&1

print "Boot benchmark saved to: ${logfile}"
