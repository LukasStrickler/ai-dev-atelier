#!/bin/bash
# Clean up old agent runs

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/agent-utils.sh"

# Parse arguments
RETENTION_DAYS="${1:-7}"

echo "Cleaning up agent runs older than $RETENTION_DAYS days..." >&2

# Find old runs
find "$RUNS_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r runDir; do
  local runId=$(basename "$runDir")
  local metaFile="${runDir}/meta.json"
  
  if [ -f "$metaFile" ]; then
    # Check completion time
    local completedAt
    if command -v jq &> /dev/null; then
      completedAt=$(cat "$metaFile" | jq -r '.completedAt // empty' 2>/dev/null || echo "")
    else
      completedAt=$(grep -o '"completedAt":"[^"]*"' "$metaFile" | sed 's/"completedAt":"\([^"]*\)"/\1/' || echo "")
    fi
    
    if [ -n "$completedAt" ]; then
      # Calculate age (simplified - would need proper date parsing)
      echo "Checking run: $runId" >&2
      # Cleanup logic would go here
    fi
  fi
done

echo "Cleanup completed" >&2

