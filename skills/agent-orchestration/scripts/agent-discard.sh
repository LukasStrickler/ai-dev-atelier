#!/bin/bash
# Discard an agent run

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/agent-utils.sh"

# Parse arguments
RUN_ID="${1:-}"

if [ -z "$RUN_ID" ]; then
  echo "Usage: $0 <runId>" >&2
  exit 1
fi

# Read metadata to get PID
META_JSON=$(read_meta_json "$RUN_ID")
if [ $? -eq 0 ] && [ -n "$META_JSON" ]; then
  if command -v jq &> /dev/null; then
    PID=$(echo "$META_JSON" | jq -r '.pid // empty')
  else
    PID=$(echo "$META_JSON" | grep -o '"pid":"[^"]*"' | sed 's/"pid":"\([^"]*\)"/\1/' || echo "")
  fi
  
  # Kill process if still running
  if [ -n "$PID" ] && [ "$PID" != "null" ] && [ "$PID" != "0" ]; then
    if check_process_alive "$PID"; then
      echo "Killing process $PID..." >&2
      kill_process_group "$PID"
    fi
  fi
fi

# Cleanup worktree
cleanup_worktree "$RUN_ID"

# Update metadata
write_meta_json "$RUN_ID" "status" "discarded" "discardedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "Discarded run: $RUN_ID"

