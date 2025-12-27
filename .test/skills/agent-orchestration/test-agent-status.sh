#!/bin/bash
# Test agent status monitoring

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPTS_DIR="${SCRIPT_DIR}/skills/agent-orchestration/scripts"

echo "=========================================="
echo "Agent Status Monitoring Test"
echo "=========================================="
echo ""

# Source utilities
source "${AGENT_SCRIPTS_DIR}/lib/agent-utils.sh"

# Test with simple prompt
PROMPT="Write a file called status-test.md with the content: 'Status test completed at $(date)'. That's all."

echo "Spawning agent..."
RUN_ID=$("${AGENT_SCRIPTS_DIR}/agent-spawn.sh" \
  --provider cursor \
  --mode work \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

echo "✓ Agent spawned with runId: $RUN_ID"
echo ""

# Get PID and status
META_JSON=$(read_meta_json "$RUN_ID")
PID=$(echo "$META_JSON" | jq -r '.pid // empty' 2>/dev/null || echo "$META_JSON" | grep -o '"pid":"[^"]*"' | sed 's/"pid":"\([^"]*\)"/\1/')
STATUS=$(echo "$META_JSON" | jq -r '.status // "unknown"' 2>/dev/null || echo "$META_JSON" | grep -o '"status":"[^"]*"' | sed 's/"status":"\([^"]*\)"/\1/' || echo "unknown")

echo "Initial Status:"
echo "  PID: $PID"
echo "  Status: $STATUS"
echo ""

# Monitor with status updates
echo "Monitoring agent (showing status every 5 seconds)..."
TIMEOUT=120
START_TIME=$(date +%s)
LAST_UPDATE=0

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  
  # Check process status
  if [ -n "$PID" ] && [ "$PID" != "null" ] && [ "$PID" != "0" ]; then
    if check_process_alive "$PID"; then
      PROCESS_STATUS="RUNNING"
      
      # Check if cursor-agent is actually running
      if check_cursor_agent_running "$PID"; then
        CURSOR_STATUS="cursor-agent active"
      else
        CURSOR_STATUS="cursor-agent not found (PID alive but no cursor-agent process)"
      fi
    else
      PROCESS_STATUS="STOPPED"
      CURSOR_STATUS="process dead"
    fi
  else
    PROCESS_STATUS="NO PID"
    CURSOR_STATUS="N/A"
  fi
  
  # Check meta.json status
  META_JSON=$(read_meta_json "$RUN_ID" 2>/dev/null || echo "{}")
  STATUS=$(echo "$META_JSON" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
  
  # Status update every 5 seconds
  if [ $((ELAPSED - LAST_UPDATE)) -ge 5 ]; then
    echo "[$(date +%H:%M:%S)] Elapsed: ${ELAPSED}s | PID Status: $PROCESS_STATUS | Meta Status: $STATUS | $CURSOR_STATUS"
    LAST_UPDATE=$ELAPSED
  fi
  
  # Check for completion
  if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ] || [ "$STATUS" = "timeout" ]; then
    echo ""
    echo "✓ Agent finished with status: $STATUS"
    break
  fi
  
  # Check timeout
  if [ $ELAPSED -gt $TIMEOUT ]; then
    echo ""
    echo "⚠ Timeout after ${TIMEOUT} seconds"
    break
  fi
  
  sleep 1
done

# Check worktree for results
WORKTREE_PATH=$(get_worktree_path "$RUN_ID" 2>/dev/null || echo "")
if [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH" ]; then
  echo ""
  echo "Files in worktree:"
  ls -la "$WORKTREE_PATH" | grep -E "(status-test|hello)" || echo "  (no test files found)"
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="

