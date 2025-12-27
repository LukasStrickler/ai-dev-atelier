#!/bin/bash
# Test 4: Research agent that only has output in out.ndjson

set -euo pipefail

echo "=========================================="
echo "Test 4: Synthesize answer from out.ndjson"
echo "=========================================="
echo ""

# Create a test run directory and manually create out.ndjson with content
TEST_RUN_ID="test-$(date +%Y%m%d-%H%M%S)-ndjson"
TEST_RUN_DIR=".ada/data/agents/runs/$TEST_RUN_ID"
mkdir -p "$TEST_RUN_DIR"

# Create a fake out.ndjson with output content
cat > "$TEST_RUN_DIR/out.ndjson" << 'EOF'
{"type":"start","timestamp":"2025-12-24T00:00:00Z","mode":"research"}
{"type":"output","timestamp":"2025-12-24T00:00:01Z","content":"Researching the topic..."}
{"type":"output","timestamp":"2025-12-24T00:00:02Z","content":"Machine learning is a subset of artificial intelligence."}
{"type":"output","timestamp":"2025-12-24T00:00:03Z","content":"It enables computers to learn from data without explicit programming."}
{"type":"output","timestamp":"2025-12-24T00:00:04Z","content":"Common techniques include neural networks, decision trees, and support vector machines."}
{"type":"warning","timestamp":"2025-12-24T00:00:05Z","message":"Some warning message"}
{"type":"complete","timestamp":"2025-12-24T00:00:06Z"}
EOF

# Create meta.json for the test
cat > "$TEST_RUN_DIR/meta.json" << EOF
{
  "runId": "$TEST_RUN_ID",
  "mode": "research",
  "status": "completed"
}
EOF

echo "Created test out.ndjson with output content"
echo ""

# Test the synthesis function directly
source skills/agent-orchestration/scripts/lib/agent-utils.sh

EXTRACTION_METHOD=""
if synthesize_answer_from_ndjson "$TEST_RUN_DIR/out.ndjson" "$TEST_RUN_DIR"; then
  EXTRACTION_METHOD="ndjson"
fi

# Check if answer.md was created
ANSWER_FILE="$TEST_RUN_DIR/answer.md"
if [ -f "$ANSWER_FILE" ]; then
  echo "✓ answer.md synthesized from out.ndjson"
  echo ""
  echo "Content:"
  cat "$ANSWER_FILE"
  echo ""
  
  if grep -q "Synthesized from Agent Output" "$ANSWER_FILE"; then
    if grep -q "Machine learning" "$ANSWER_FILE"; then
      if ! grep -q "warning message" "$ANSWER_FILE"; then
        echo "✅ Test 4 PASSED: NDJSON synthesis worked correctly (warnings filtered)"
        rm -rf "$TEST_RUN_DIR"
        exit 0
      else
        echo "❌ Test 4 FAILED: Warnings were not filtered"
        rm -rf "$TEST_RUN_DIR"
        exit 1
      fi
    else
      echo "❌ Test 4 FAILED: Content not found in answer"
      rm -rf "$TEST_RUN_DIR"
      exit 1
    fi
  else
    echo "❌ Test 4 FAILED: Answer doesn't contain expected header"
    rm -rf "$TEST_RUN_DIR"
    exit 1
  fi
else
  echo "❌ Test 4 FAILED: answer.md not created from out.ndjson"
  rm -rf "$TEST_RUN_DIR"
  exit 1
fi

