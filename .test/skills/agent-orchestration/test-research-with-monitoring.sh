#!/bin/bash
# Test research agent with real-time monitoring

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPTS_DIR="${SCRIPT_DIR}/skills/agent-orchestration/scripts"

echo "=========================================="
echo "Research Agent Test - With Real-Time Monitoring"
echo "=========================================="
echo ""

# Simple research prompt (not too complex to avoid long waits)
PROMPT="Research information retrieval systems. Write a brief answer (3-4 paragraphs) about what they are, key components, and modern approaches. Use Tavily search if needed. Write your answer to answer.md."

echo "Spawning research agent..."
RUN_ID=$("${AGENT_SCRIPTS_DIR}/agent-spawn.sh" \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

echo "✓ Agent spawned with runId: $RUN_ID"
echo ""

# Get initial status
source "${AGENT_SCRIPTS_DIR}/lib/agent-utils.sh"
META_JSON=$(read_meta_json "$RUN_ID")
PID=$(echo "$META_JSON" | jq -r '.pid // empty' 2>/dev/null || echo "$META_JSON" | grep -o '"pid":"[^"]*"' | sed 's/"pid":"\([^"]*\)"/\1/')

echo "Agent PID: $PID"
echo ""

# Monitor with detailed status
echo "Monitoring agent (updates every 5 seconds)..."
echo "Press Ctrl+C to stop monitoring (agent will continue in background)"
echo ""

TIMEOUT=300  # 5 minutes max
START_TIME=$(date +%s)
LAST_UPDATE=0
OUT_NDJSON=".ada/data/agents/runs/${RUN_ID}/out.ndjson"

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  
  # Check PID status
  if [ -n "$PID" ] && [ "$PID" != "null" ] && [ "$PID" != "0" ]; then
    if check_process_alive "$PID"; then
      PID_STATUS="✓ ALIVE"
      
      # Check for cursor-agent processes
      CURSOR_PROCESSES=$(ps aux | grep -E "[c]ursor-agent" | wc -l | tr -d ' ')
      if [ "$CURSOR_PROCESSES" -gt 0 ]; then
        CURSOR_STATUS="cursor-agent processes: $CURSOR_PROCESSES"
      else
        CURSOR_STATUS="no cursor-agent processes found"
      fi
    else
      PID_STATUS="✗ DEAD"
      CURSOR_STATUS="process finished"
    fi
  else
    PID_STATUS="NO PID"
    CURSOR_STATUS="N/A"
  fi
  
  # Check meta.json status
  META_JSON=$(read_meta_json "$RUN_ID" 2>/dev/null || echo "{}")
  STATUS=$(echo "$META_JSON" | jq -r '.status // "running"' 2>/dev/null || echo "running")
  
  # Check out.ndjson for progress
  PROGRESS_LINES=0
  LAST_MESSAGE=""
  if [ -f "$OUT_NDJSON" ]; then
    PROGRESS_LINES=$(wc -l < "$OUT_NDJSON" 2>/dev/null || echo "0")
    if [ "$PROGRESS_LINES" -gt 0 ]; then
      LAST_MESSAGE=$(tail -1 "$OUT_NDJSON" 2>/dev/null | jq -r '.message // .type // ""' 2>/dev/null || echo "")
      if [ -z "$LAST_MESSAGE" ]; then
        LAST_MESSAGE=$(tail -1 "$OUT_NDJSON" 2>/dev/null | grep -o '"message":"[^"]*"' | sed 's/"message":"\([^"]*\)"/\1/' | tail -1 || echo "")
      fi
    fi
  fi
  
  # Status update every 5 seconds
  if [ $((ELAPSED - LAST_UPDATE)) -ge 5 ]; then
    printf "[%s] Elapsed: %3ds | PID: %s | Status: %-10s | Output lines: %3d\n" \
      "$(date +%H:%M:%S)" "$ELAPSED" "$PID_STATUS" "$STATUS" "$PROGRESS_LINES"
    if [ -n "$LAST_MESSAGE" ] && [ ${#LAST_MESSAGE} -lt 80 ]; then
      echo "  Last: $LAST_MESSAGE"
    fi
    if [ -n "$CURSOR_STATUS" ]; then
      echo "  $CURSOR_STATUS"
    fi
    LAST_UPDATE=$ELAPSED
  fi
  
  # Check for completion
  if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ] || [ "$STATUS" = "timeout" ]; then
    echo ""
    echo "✓ Agent finished with status: $STATUS"
    break
  fi
  
  # Check if process is dead but status not updated
  if [ "$PID_STATUS" = "✗ DEAD" ] && [ "$STATUS" = "running" ]; then
    echo ""
    echo "⚠ Process died but status not updated - checking completion..."
    sleep 2
    # Re-check status
    META_JSON=$(read_meta_json "$RUN_ID" 2>/dev/null || echo "{}")
    STATUS=$(echo "$META_JSON" | jq -r '.status // "running"' 2>/dev/null || echo "running")
    if [ "$STATUS" = "running" ]; then
      echo "  Updating status to completed..."
      write_meta_json "$RUN_ID" "status" "completed" "completedAt" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      STATUS="completed"
    fi
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

# Check results
echo ""
echo "=========================================="
echo "Checking Results"
echo "=========================================="

WORKTREE_PATH=$(get_worktree_path "$RUN_ID" 2>/dev/null || echo "")
if [ -n "$WORKTREE_PATH" ] && [ -d "$WORKTREE_PATH" ]; then
  if [ -f "${WORKTREE_PATH}/answer.md" ]; then
    ANSWER_SIZE=$(wc -c < "${WORKTREE_PATH}/answer.md" 2>/dev/null || echo "0")
    echo "✓ answer.md found (${ANSWER_SIZE} bytes)"
    echo ""
    echo "Preview:"
    head -10 "${WORKTREE_PATH}/answer.md"
  else
    echo "✗ answer.md not found"
  fi
fi

# Show recent output
if [ -f "$OUT_NDJSON" ]; then
  echo ""
  echo "Recent output (last 5 lines):"
  tail -5 "$OUT_NDJSON" | jq -r '.message // .type // .' 2>/dev/null || tail -5 "$OUT_NDJSON"
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="

