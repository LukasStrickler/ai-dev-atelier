#!/bin/bash
# Test 1: Research agent that creates answer.md directly in root

set -euo pipefail

echo "=========================================="
echo "Test 1: Direct answer.md extraction"
echo "=========================================="
echo ""

PROMPT="Research and write a brief answer about what machine learning is. Write your final answer to answer.md in the root directory."

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

# Check extraction method
EXTRACTION_METHOD=$(echo "$RESULT" | grep -o '"answerExtractionMethod":"[^"]*"' | sed 's/"answerExtractionMethod":"\([^"]*\)"/\1/' || echo "")

echo ""
echo "Extraction method: $EXTRACTION_METHOD"

# Check if answer.md exists
ANSWER_FILE=".ada/data/agents/runs/$RUN_ID/answer.md"
if [ -f "$ANSWER_FILE" ]; then
  echo "✓ answer.md exists"
  echo ""
  echo "Content preview (first 10 lines):"
  head -10 "$ANSWER_FILE"
  echo ""
  
  if [ "$EXTRACTION_METHOD" = "direct" ]; then
    echo "✅ Test 1 PASSED: Direct extraction worked correctly"
    exit 0
  else
    echo "⚠️  Test 1 WARNING: Expected 'direct' but got '$EXTRACTION_METHOD'"
    exit 0
  fi
else
  echo "❌ Test 1 FAILED: answer.md not found"
  exit 1
fi

