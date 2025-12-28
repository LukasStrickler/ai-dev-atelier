#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/../references/subagent-task-brief.md"

OUTPUT="./subagent-task-brief.md"
FORCE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    *)
      echo "Usage: $0 [--output <path>] [--force]" >&2
      exit 1
      ;;
  esac
done

if [ -f "$OUTPUT" ] && [ "$FORCE" != "true" ]; then
  echo "Error: $OUTPUT already exists. Use --force to overwrite." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
cp "$TEMPLATE" "$OUTPUT"

echo "Created subagent task brief at: $OUTPUT" >&2
