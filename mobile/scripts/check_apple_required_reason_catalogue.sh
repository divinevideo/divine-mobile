#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
attempt=1
while (( attempt <= 3 )); do
  python3 "$SCRIPT_DIR/lib/apple_required_reason_probe.py" "$@"
  status=$?
  if (( status != 2 )); then
    exit "$status"
  fi
  if (( attempt < 3 )); then
    echo "Retrying after operational failure ($attempt/3)..." >&2
  fi
  ((attempt += 1))
done
exit 2
