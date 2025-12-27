#!/bin/bash
# Quick status check for agent runs

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/agent-utils.sh"

# Parse arguments
RUN_ID="${1:-}"

if [ -z "$RUN_ID" ]; then
  echo "Usage: $0 <runId>" >&2
  echo "" >&2
  echo "Quick status check for an agent run." >&2
  exit 1
fi

# Read metadata
META_JSON=$(read_meta_json "$RUN_ID")
if [ $? -ne 0 ] || [ -z "$META_JSON" ]; then
  echo "Error: Could not read metadata for runId: $RUN_ID" >&2
  exit 1
fi

# Extract fields
if command -v jq &> /dev/null; then
  RUN_ID_VAL=$(echo "$META_JSON" | jq -r '.runId // empty')
  STATUS=$(echo "$META_JSON" | jq -r '.status // "unknown"')
  PROCESS_STATUS=$(echo "$META_JSON" | jq -r '.processStatus // "unknown"')
  PID=$(echo "$META_JSON" | jq -r '.pid // empty')
  PROVIDER=$(echo "$META_JSON" | jq -r '.provider // "unknown"')
  MODE=$(echo "$META_JSON" | jq -r '.mode // "unknown"')
  STARTED_AT=$(echo "$META_JSON" | jq -r '.startedAt // ""')
  COMPLETED_AT=$(echo "$META_JSON" | jq -r '.completedAt // ""')
  LAST_CHECK=$(echo "$META_JSON" | jq -r '.lastCheckAt // ""')
  ELAPSED=$(echo "$META_JSON" | jq -r '.elapsedSeconds // "0"')
  CURSOR_PROCESSES=$(echo "$META_JSON" | jq -r '.cursorAgentProcesses // "0"')
else
  # Basic extraction without jq
  RUN_ID_VAL=$(echo "$META_JSON" | grep -o '"runId":"[^"]*"' | sed 's/"runId":"\([^"]*\)"/\1/' || echo "")
  STATUS=$(echo "$META_JSON" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/' || echo "unknown")
  PROCESS_STATUS=$(echo "$META_JSON" | grep -o '"processStatus":"[^"]*"' | sed 's/"processStatus":"\([^"]*\)"/\1/' || echo "unknown")
  PID=$(echo "$META_JSON" | grep -o '"pid":"[^"]*"' | sed 's/"pid":"\([^"]*\)"/\1/' || echo "")
  PROVIDER=$(echo "$META_JSON" | grep -o '"provider":"[^"]*"' | sed 's/"provider":"\([^"]*\)"/\1/' || echo "unknown")
  MODE=$(echo "$META_JSON" | grep -o '"mode":"[^"]*"' | sed 's/"mode":"\([^"]*\)"/\1/' || echo "unknown")
  STARTED_AT=$(echo "$META_JSON" | grep -o '"startedAt":"[^"]*"' | sed 's/"startedAt":"\([^"]*\)"/\1/' || echo "")
  COMPLETED_AT=$(echo "$META_JSON" | grep -o '"completedAt":"[^"]*"' | sed 's/"completedAt":"\([^"]*\)"/\1/' || echo "")
  LAST_CHECK=$(echo "$META_JSON" | grep -o '"lastCheckAt":"[^"]*"' | sed 's/"lastCheckAt":"\([^"]*\)"/\1/' || echo "")
  ELAPSED=$(echo "$META_JSON" | grep -o '"elapsedSeconds":"[^"]*"' | sed 's/"elapsedSeconds":"\([^"]*\)"/\1/' || echo "0")
  CURSOR_PROCESSES=$(echo "$META_JSON" | grep -o '"cursorAgentProcesses":"[^"]*"' | sed 's/"cursorAgentProcesses":"\([^"]*\)"/\1/' || echo "0")
fi

# Check if process is alive
PID_ALIVE="unknown"
if [ -n "$PID" ] && [ "$PID" != "null" ] && [ "$PID" != "0" ]; then
  if check_process_alive "$PID"; then
    PID_ALIVE="alive"
  else
    PID_ALIVE="dead"
  fi
fi

# Determine color based on status
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_CYAN="\033[36m"

case "$STATUS" in
  "running")
    STATUS_COLOR="$COLOR_GREEN"
    ;;
  "completed")
    STATUS_COLOR="$COLOR_YELLOW"
    ;;
  "failed"|"timeout")
    STATUS_COLOR="$COLOR_RED"
    ;;
  *)
    STATUS_COLOR="$COLOR_CYAN"
    ;;
esac

# Display status
echo "=========================================="
echo "Agent Status: $RUN_ID"
echo "=========================================="
echo ""
echo -e "Status:        ${STATUS_COLOR}${STATUS}${COLOR_RESET}"
echo "Process:       $PROCESS_STATUS"
echo "Provider:      $PROVIDER"
echo "Mode:          $MODE"
echo ""
echo "PID:           $PID ($PID_ALIVE)"
if [ "$PROVIDER" = "cursor" ] && [ "$CURSOR_PROCESSES" != "0" ]; then
  echo "Cursor Procs:  $CURSOR_PROCESSES"
fi
echo ""
echo "Started:       ${STARTED_AT:-N/A}"
if [ -n "$COMPLETED_AT" ]; then
  echo "Completed:     $COMPLETED_AT"
fi
if [ -n "$LAST_CHECK" ]; then
  echo "Last Check:    $LAST_CHECK"
fi
echo "Elapsed:       ${ELAPSED}s"
echo ""

# Check artifacts
RUN_DIR=$(get_run_directory "$RUN_ID")
if [ -d "$RUN_DIR" ]; then
  echo "Artifacts:"
  if [ -f "${RUN_DIR}/patch.diff" ]; then
    PATCH_SIZE=$(wc -c < "${RUN_DIR}/patch.diff" 2>/dev/null || echo "0")
    echo "  ✓ patch.diff (${PATCH_SIZE} bytes)"
  else
    echo "  ✗ patch.diff (missing)"
  fi
  
  if [ -f "${RUN_DIR}/changed_files.txt" ]; then
    FILE_COUNT=$(wc -l < "${RUN_DIR}/changed_files.txt" 2>/dev/null || echo "0")
    echo "  ✓ changed_files.txt (${FILE_COUNT} files)"
  else
    echo "  ✗ changed_files.txt (missing)"
  fi
  
  if [ "$MODE" = "work" ] && [ -f "${RUN_DIR}/diffstat.txt" ]; then
    echo "  ✓ diffstat.txt"
  elif [ "$MODE" = "work" ]; then
    echo "  ✗ diffstat.txt (missing)"
  fi
  
  if [ "$MODE" = "research" ] && [ -f "${RUN_DIR}/answer.md" ]; then
    ANSWER_SIZE=$(wc -c < "${RUN_DIR}/answer.md" 2>/dev/null || echo "0")
    echo "  ✓ answer.md (${ANSWER_SIZE} bytes)"
  elif [ "$MODE" = "research" ]; then
    echo "  ✗ answer.md (missing)"
  fi
fi

echo ""
echo "=========================================="

