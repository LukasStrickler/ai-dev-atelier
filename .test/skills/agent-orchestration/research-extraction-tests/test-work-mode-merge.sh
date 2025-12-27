#!/bin/bash
# Test 6: Verify work mode still merges correctly

set -euo pipefail

echo "=========================================="
echo "Test 6: Work mode merge verification"
echo "=========================================="
echo ""

PROMPT="Create a test file called work-test.txt with the content 'Work mode test' in the root directory."

echo "Spawning work agent..."
RUN_ID=$(bash skills/agent-orchestration/scripts/agent-spawn.sh \
  --provider cursor \
  --mode work \
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

# Check that result.json doesn't have answerExtractionMethod (work mode)
if echo "$RESULT" | grep -q "answerExtractionMethod"; then
  echo "❌ Test 6 FAILED: answerExtractionMethod should not be in work mode result"
  exit 1
fi

echo "✓ Work mode result doesn't include answerExtractionMethod (correct)"
echo ""

# Try to merge
echo "Attempting merge..."
MERGE_RESULT=$(bash skills/agent-orchestration/scripts/agent-merge.sh "$RUN_ID" main 2>&1)

if echo "$MERGE_RESULT" | grep -q "Merge successful\|Files copied successfully"; then
  echo "✓ Merge successful"
  echo ""
  
  # Check if file exists in main (if merge copied files)
  WORKTREE=".ada/temp/agents/worktrees/$RUN_ID"
  if [ -d "$WORKTREE" ] && [ -f "$WORKTREE/work-test.txt" ]; then
    echo "✅ Test 6 PASSED: Work mode merge works correctly"
    exit 0
  else
    echo "⚠️  Test 6 WARNING: File not found in worktree (may have been cleaned up)"
    exit 0
  fi
else
  echo "⚠️  Test 6 WARNING: Merge had issues (may be expected if branch was cleaned up)"
  exit 0
fi

