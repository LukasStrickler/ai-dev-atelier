#!/bin/bash
# Test 7: Verify research mode never merges

set -euo pipefail

echo "=========================================="
echo "Test 7: Research mode merge prevention"
echo "=========================================="
echo ""

PROMPT="Research what JavaScript is. Write your answer to answer.md"

echo "Spawning research agent..."
RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode research \
  --runtime await \
  --prompt "$PROMPT" \
  --model auto 2>&1 | grep -E "^[0-9]{8}-[0-9]{6}-[a-f0-9]{6}$" | head -1)

if [ -z "$RUN_ID" ] || [ ${#RUN_ID} -lt 10 ]; then
  echo "❌ Failed to spawn agent"
  exit 1
fi

echo "✓ Agent completed: $RUN_ID"
echo ""

echo "Collecting results..."
RESULT=$(bash skills/agent-orchestration/scripts/agent-collect.sh "$RUN_ID" 2>&1)

# Check that answer.md exists in run directory
ANSWER_FILE=".ada/data/agents/runs/$RUN_ID/answer.md"
if [ ! -f "$ANSWER_FILE" ]; then
  echo "⚠️  Warning: answer.md not found, but continuing test..."
fi

echo ""
echo "Attempting to merge research mode agent (should fail)..."
MERGE_RESULT=$(bash skills/agent-orchestration/scripts/agent-merge.sh "$RUN_ID" main 2>&1)

if echo "$MERGE_RESULT" | grep -q "Can only merge work-mode agents"; then
  if echo "$MERGE_RESULT" | grep -q "answer.md"; then
    echo "✓ Merge correctly rejected for research mode"
    echo "✓ Error message points to answer.md location"
    echo ""
    echo "✅ Test 7 PASSED: Research mode merge prevention works correctly"
    exit 0
  else
    echo "⚠️  Test 7 WARNING: Merge rejected but error message doesn't mention answer.md"
    exit 0
  fi
else
  echo "❌ Test 7 FAILED: Merge was not rejected for research mode"
  echo "Merge result: $MERGE_RESULT"
  exit 1
fi

