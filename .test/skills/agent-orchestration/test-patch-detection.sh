#!/bin/bash
# Test script to validate patch-based result detection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPTS_DIR="${SCRIPT_DIR}/skills/agent-orchestration/scripts"

echo "=========================================="
echo "Testing Patch-Based Result Detection"
echo "=========================================="
echo ""

# Test 1: Spawn a research agent with a simple prompt
echo "Test 1: Spawning research agent..."
RUN_ID=$("${AGENT_SCRIPTS_DIR}/agent-spawn.sh" \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "Write a brief answer (2-3 sentences) about what information retrieval systems are. Write your answer to answer.md in the root directory." \
  --model auto)

echo "✓ Agent spawned with runId: $RUN_ID"
echo ""

# Test 2: Wait for agent to complete (with timeout)
echo "Test 2: Waiting for agent to complete (max 60 seconds)..."
TIMEOUT=60
START_TIME=$(date +%s)

while true; do
  # Check if process is still running
  META_JSON=$("${AGENT_SCRIPTS_DIR}/lib/agent-utils.sh" 2>/dev/null || echo "")
  if [ -f ".ada/data/agents/runs/${RUN_ID}/meta.json" ]; then
    STATUS=$(grep -o '"status":"[^"]*"' ".ada/data/agents/runs/${RUN_ID}/meta.json" | sed 's/"status":"\([^"]*\)"/\1/' || echo "running")
    if [ "$STATUS" = "completed" ] || [ "$STATUS" = "failed" ]; then
      break
    fi
  fi
  
  # Check timeout
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))
  if [ $ELAPSED -gt $TIMEOUT ]; then
    echo "⚠ Timeout after ${TIMEOUT} seconds"
    break
  fi
  
  sleep 2
done

echo "✓ Agent completed (or timeout reached)"
echo ""

# Test 3: Collect results and verify patch analysis
echo "Test 3: Collecting results and verifying patch analysis..."
RESULT_JSON=$("${AGENT_SCRIPTS_DIR}/agent-collect.sh" "$RUN_ID" 2>&1)

# Check if result.json was created
if [ ! -f ".ada/data/agents/runs/${RUN_ID}/result.json" ]; then
  echo "❌ ERROR: result.json not found"
  exit 1
fi

echo "✓ result.json created"
echo ""

# Test 4: Verify patch was generated
echo "Test 4: Verifying patch was generated..."
if [ ! -f ".ada/data/agents/runs/${RUN_ID}/patch.diff" ]; then
  echo "❌ ERROR: patch.diff not found"
  exit 1
fi

PATCH_SIZE=$(wc -c < ".ada/data/agents/runs/${RUN_ID}/patch.diff" 2>/dev/null || echo "0")
if [ "$PATCH_SIZE" -eq 0 ]; then
  echo "⚠ WARNING: patch.diff is empty (no changes detected)"
else
  echo "✓ patch.diff exists and has content (${PATCH_SIZE} bytes)"
fi
echo ""

# Test 5: Verify patch analysis in result.json
echo "Test 5: Verifying patch analysis in result.json..."
if command -v jq &> /dev/null; then
  PATCH_ANALYSIS=$(jq -r '.patchAnalysis' ".ada/data/agents/runs/${RUN_ID}/result.json" 2>/dev/null || echo "{}")
  
  if [ "$PATCH_ANALYSIS" = "null" ] || [ -z "$PATCH_ANALYSIS" ]; then
    echo "❌ ERROR: patchAnalysis field missing or null in result.json"
    exit 1
  fi
  
  HAS_CHANGES=$(echo "$PATCH_ANALYSIS" | jq -r '.hasChanges // false' 2>/dev/null || echo "false")
  WORK_DETECTED=$(echo "$PATCH_ANALYSIS" | jq -r '.workDetected // false' 2>/dev/null || echo "false")
  ANSWER_LOCATION=$(echo "$PATCH_ANALYSIS" | jq -r '.answerLocation // null' 2>/dev/null || echo "null")
  PATCH_SIZE_ANALYSIS=$(echo "$PATCH_ANALYSIS" | jq -r '.patchSize // 0' 2>/dev/null || echo "0")
  
  echo "  - hasChanges: $HAS_CHANGES"
  echo "  - workDetected: $WORK_DETECTED"
  echo "  - answerLocation: $ANSWER_LOCATION"
  echo "  - patchSize: $PATCH_SIZE_ANALYSIS"
  
  if [ "$HAS_CHANGES" = "true" ] || [ "$WORK_DETECTED" = "true" ]; then
    echo "✓ Patch analysis indicates work was done"
  else
    echo "⚠ WARNING: Patch analysis indicates no work detected"
  fi
else
  echo "⚠ jq not available, skipping detailed patch analysis verification"
  # Basic check
  if grep -q "patchAnalysis" ".ada/data/agents/runs/${RUN_ID}/result.json"; then
    echo "✓ patchAnalysis field exists in result.json"
  else
    echo "❌ ERROR: patchAnalysis field missing in result.json"
    exit 1
  fi
fi
echo ""

# Test 6: Verify answer.md extraction (if research mode)
echo "Test 6: Verifying answer.md extraction..."
if [ -f ".ada/data/agents/runs/${RUN_ID}/answer.md" ]; then
  ANSWER_SIZE=$(wc -c < ".ada/data/agents/runs/${RUN_ID}/answer.md" 2>/dev/null || echo "0")
  if [ "$ANSWER_SIZE" -gt 50 ]; then
    echo "✓ answer.md extracted successfully (${ANSWER_SIZE} bytes)"
    echo ""
    echo "First 200 characters of answer.md:"
    head -c 200 ".ada/data/agents/runs/${RUN_ID}/answer.md" | sed 's/$/.../'
    echo ""
  else
    echo "⚠ WARNING: answer.md exists but is very small (${ANSWER_SIZE} bytes)"
  fi
else
  echo "⚠ WARNING: answer.md not found in run directory"
  # Check if it exists in worktree
  WORKTREE_PATH=$(grep -o '"worktreePath":"[^"]*"' ".ada/data/agents/runs/${RUN_ID}/meta.json" | sed 's/"worktreePath":"\([^"]*\)"/\1/' || echo "")
  if [ -n "$WORKTREE_PATH" ] && [ -f "${WORKTREE_PATH}/answer.md" ]; then
    echo "  (but answer.md exists in worktree: ${WORKTREE_PATH}/answer.md)"
  fi
fi
echo ""

# Test 7: Display summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Run ID: $RUN_ID"
echo "Result JSON: .ada/data/agents/runs/${RUN_ID}/result.json"
echo "Patch Diff: .ada/data/agents/runs/${RUN_ID}/patch.diff"
echo "Changed Files: .ada/data/agents/runs/${RUN_ID}/changed_files.txt"
if [ -f ".ada/data/agents/runs/${RUN_ID}/answer.md" ]; then
  echo "Answer: .ada/data/agents/runs/${RUN_ID}/answer.md"
fi
echo ""

# Display result.json (formatted if jq available)
if command -v jq &> /dev/null; then
  echo "Result JSON (formatted):"
  jq '.' ".ada/data/agents/runs/${RUN_ID}/result.json" 2>/dev/null || cat ".ada/data/agents/runs/${RUN_ID}/result.json"
else
  echo "Result JSON:"
  cat ".ada/data/agents/runs/${RUN_ID}/result.json"
fi
echo ""

echo "=========================================="
echo "Test Complete"
echo "=========================================="

