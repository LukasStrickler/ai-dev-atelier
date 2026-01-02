#!/bin/bash
# Simple test: Just write hello.md to verify agent can write files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPTS_DIR="${SCRIPT_DIR}/skills/agent-orchestration/scripts"

echo "=========================================="
echo "Simple Write Test - Verify Agent Can Write Files"
echo "=========================================="
echo ""

# Test with a very simple prompt
PROMPT="Write a file called hello.md in the root of this directory with the content: 'Hello from the agent! This file was created at $(date)'. That's all - just create this one file."

echo "Spawning agent with simple write task..."
RUN_ID=$("${AGENT_SCRIPTS_DIR}/agent-spawn.sh" \
  --provider cursor \
  --mode work \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto)

echo "✓ Agent spawned with runId: $RUN_ID"
echo ""

# Wait a moment for meta.json to be created
echo "Waiting for metadata to be created..."
for i in {1..10}; do
  if [ -f ".ada/data/agents/runs/${RUN_ID}/meta.json" ]; then
    break
  fi
  sleep 0.5
done

# Get worktree path
WORKTREE_PATH=$(grep -o '"worktreePath":"[^"]*"' ".ada/data/agents/runs/${RUN_ID}/meta.json" 2>/dev/null | sed 's/"worktreePath":"\([^"]*\)"/\1/' || echo "")

if [ -z "$WORKTREE_PATH" ]; then
  echo "⚠ WARNING: Could not find worktree path in meta.json"
  echo "meta.json contents:"
  cat ".ada/data/agents/runs/${RUN_ID}/meta.json" 2>/dev/null || echo "File not found"
  echo ""
  # Try to find worktree by runId
  WORKTREE_PATH=".ada/temp/agents/worktrees/${RUN_ID}"
  if [ ! -d "$WORKTREE_PATH" ]; then
    echo "❌ ERROR: Worktree directory not found at $WORKTREE_PATH"
    exit 1
  fi
  echo "Found worktree at: $WORKTREE_PATH"
fi

echo "Worktree: $WORKTREE_PATH"
echo ""

# Monitor for up to 2 minutes
echo "Monitoring agent (max 2 minutes)..."
TIMEOUT=120
START_TIME=$(date +%s)

while true; do
  # Check if hello.md exists
  if [ -f "${WORKTREE_PATH}/hello.md" ]; then
    echo ""
    echo "✓ SUCCESS: hello.md found!"
    echo ""
    echo "Content:"
    cat "${WORKTREE_PATH}/hello.md"
    echo ""
    break
  fi
  
  # Check process
  PID=$(grep -o '"pid":[0-9]*' ".ada/data/agents/runs/${RUN_ID}/meta.json" 2>/dev/null | grep -o '[0-9]*' || echo "")
  if [ -n "$PID" ]; then
    if kill -0 "$PID" 2>/dev/null; then
      echo -n "."
    else
      echo ""
      echo "⚠ Process finished but hello.md not found"
      break
    fi
  fi
  
  # Check timeout
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  if [ $ELAPSED -gt $TIMEOUT ]; then
    echo ""
    echo "⚠ Timeout after ${TIMEOUT} seconds"
    break
  fi
  
  sleep 2
done

# Check out.ndjson for any output
if [ -f ".ada/data/agents/runs/${RUN_ID}/out.ndjson" ]; then
  echo ""
  echo "Agent output (out.ndjson):"
  echo "----------------------------------------"
  head -20 ".ada/data/agents/runs/${RUN_ID}/out.ndjson"
  echo "----------------------------------------"
  echo ""
fi

# Final check
if [ -f "${WORKTREE_PATH}/hello.md" ]; then
  echo "✅ TEST PASSED: Agent successfully wrote hello.md"
  exit 0
else
  echo "❌ TEST FAILED: hello.md was not created"
  echo ""
  echo "Files in worktree:"
  find "$WORKTREE_PATH" -maxdepth 1 | head -10
  exit 1
fi

