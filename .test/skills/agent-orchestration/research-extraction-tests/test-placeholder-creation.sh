#!/bin/bash
# Test 5: Research agent that fails all methods (placeholder creation)

set -euo pipefail

echo "=========================================="
echo "Test 5: Placeholder creation when all methods fail"
echo "=========================================="
echo ""

# Create a test run directory with no answer.md, empty patch, and empty ndjson
TEST_RUN_ID="test-$(date +%Y%m%d-%H%M%S)-placeholder"
TEST_RUN_DIR=".ada/data/agents/runs/$TEST_RUN_ID"
mkdir -p "$TEST_RUN_DIR"

# Create empty patch and ndjson
echo "# No changes" > "$TEST_RUN_DIR/patch.diff"
echo '{"type":"start"}' > "$TEST_RUN_DIR/out.ndjson"

# Create meta.json for the test
cat > "$TEST_RUN_DIR/meta.json" << EOF
{
  "runId": "$TEST_RUN_ID",
  "mode": "research",
  "status": "completed"
}
EOF

echo "Created test with no answer.md, empty patch, and minimal ndjson"
echo ""

# Test the extraction function directly
source skills/agent-orchestration/scripts/lib/agent-utils.sh

EXTRACTION_METHOD=""
# Use a non-existent workspace path to ensure all methods fail
if extract_answer_file "/nonexistent/workspace" "$TEST_RUN_DIR" "EXTRACTION_METHOD"; then
  echo "⚠️  Unexpected success"
else
  echo "Extraction failed as expected"
fi

# Check if placeholder answer.md was created
ANSWER_FILE="$TEST_RUN_DIR/answer.md"
if [ -f "$ANSWER_FILE" ]; then
  echo "✓ Placeholder answer.md created"
  echo ""
  echo "Content:"
  cat "$ANSWER_FILE"
  echo ""
  
  if grep -q "Answer Not Found" "$ANSWER_FILE"; then
    if [ "$EXTRACTION_METHOD" = "failed" ]; then
      echo "✅ Test 5 PASSED: Placeholder created correctly when all methods fail"
      rm -rf "$TEST_RUN_DIR"
      exit 0
    else
      echo "⚠️  Test 5 WARNING: Expected 'failed' but got '$EXTRACTION_METHOD'"
      rm -rf "$TEST_RUN_DIR"
      exit 0
    fi
  else
    echo "❌ Test 5 FAILED: Placeholder doesn't contain expected message"
    rm -rf "$TEST_RUN_DIR"
    exit 1
  fi
else
  echo "❌ Test 5 FAILED: Placeholder answer.md not created"
  rm -rf "$TEST_RUN_DIR"
  exit 1
fi

