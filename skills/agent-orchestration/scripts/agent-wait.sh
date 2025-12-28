#!/bin/bash
# Wait for agent completion

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/agent-utils.sh"
source "${SCRIPT_DIR}/lib/provider-interface.sh"

# Parse arguments
RUN_ID="${1:-}"
TIMEOUT="${2:-3600}"

if [ -z "$RUN_ID" ]; then
  echo "Usage: $0 <runId> [timeout]" >&2
  exit 1
fi

# Read metadata
META_JSON=$(read_meta_json "$RUN_ID")
if [ $? -ne 0 ] || [ -z "$META_JSON" ]; then
  echo "Error: Could not read metadata for runId: $RUN_ID" >&2
  exit 1
fi

# Extract PID and provider
PID=""
PROVIDER=""
OUT_NDJSON=""

if command -v jq &> /dev/null; then
  PID=$(echo "$META_JSON" | jq -r '.pid // empty')
  PROVIDER=$(echo "$META_JSON" | jq -r '.provider // "cursor"')
  RUN_DIR=$(get_run_directory "$RUN_ID")
  OUT_NDJSON="${RUN_DIR}/out.ndjson"
else
  # Basic extraction without jq
  PID=$(echo "$META_JSON" | grep -o '"pid":"[^"]*"' | sed 's/"pid":"\([^"]*\)"/\1/' || echo "")
  PROVIDER=$(echo "$META_JSON" | grep -o '"provider":"[^"]*"' | sed 's/"provider":"\([^"]*\)"/\1/' || echo "cursor")
  RUN_DIR=$(get_run_directory "$RUN_ID")
  OUT_NDJSON="${RUN_DIR}/out.ndjson"
fi

# Initial status update
update_process_status "$RUN_ID" "$PID" "0"

# Verify process exists
if ! check_process_alive "$PID"; then
  # Process already done
  elapsed=$(read_meta_json "$RUN_ID" "elapsedSeconds" 2>/dev/null || echo "0")
  update_process_status "$RUN_ID" "$PID" "$elapsed"
  write_meta_json "$RUN_ID" "status" "completed" "completedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  exit 0
fi

# Monitor process with timeout and status updates
echo "Waiting for agent $RUN_ID (PID: $PID) to complete..." >&2
if monitor_process "$PID" "$TIMEOUT" "$RUN_ID"; then
  # Process completed
  echo "Agent $RUN_ID completed successfully" >&2
  elapsed=$(read_meta_json "$RUN_ID" "elapsedSeconds" 2>/dev/null || echo "0")
  update_process_status "$RUN_ID" "$PID" "$elapsed"
  write_meta_json "$RUN_ID" "status" "completed" "completedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  exit 0
else
  EXIT_CODE=$?
  elapsed=$(read_meta_json "$RUN_ID" "elapsedSeconds" 2>/dev/null || echo "0")
  update_process_status "$RUN_ID" "$PID" "$elapsed"
  
  if [ $EXIT_CODE -eq 2 ]; then
    # Timeout
    echo "Agent $RUN_ID timed out after ${TIMEOUT}s" >&2
    write_meta_json "$RUN_ID" "status" "timeout" "completedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    exit 2
  else
    # Process failed
    echo "Agent $RUN_ID failed" >&2
    write_meta_json "$RUN_ID" "status" "failed" "completedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    exit 1
  fi
fi
