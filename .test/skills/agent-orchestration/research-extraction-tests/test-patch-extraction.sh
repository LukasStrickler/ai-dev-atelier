#!/bin/bash
# Test 3: Research agent that doesn't create answer.md but has content in patch

set -euo pipefail

echo "=========================================="
echo "Test 3: Extract answer from patch.diff"
echo "=========================================="
echo ""

# Create a test run directory and manually create a patch with answer.md content
TEST_RUN_ID="test-$(date +%Y%m%d-%H%M%S)-patch"
TEST_RUN_DIR=".ada/data/agents/runs/$TEST_RUN_ID"
mkdir -p "$TEST_RUN_DIR"

# Create a fake patch.diff with answer.md content
cat > "$TEST_RUN_DIR/patch.diff" << 'EOF'
# Diff of uncommitted changes
+++ b/answer.md
@@ -0,0 +1,5 @@
+# Test Answer from Patch
+
+This is a test answer that should be extracted from the patch file.
+
+The extraction method should be "patch".
EOF

# Create meta.json for the test
cat > "$TEST_RUN_DIR/meta.json" << EOF
{
  "runId": "$TEST_RUN_ID",
  "mode": "research",
  "status": "completed"
}
EOF

echo "Created test patch with answer.md content"
echo ""

# Test the extraction function directly
source skills/agent-orchestration/scripts/lib/agent-utils.sh

EXTRACTION_METHOD=""
if extract_answer_from_patch "$TEST_RUN_DIR/patch.diff" "$TEST_RUN_DIR"; then
  EXTRACTION_METHOD="patch"
fi

# Check if answer.md was created
ANSWER_FILE="$TEST_RUN_DIR/answer.md"
if [ -f "$ANSWER_FILE" ]; then
  echo "✓ answer.md extracted from patch"
  echo ""
  echo "Content:"
  cat "$ANSWER_FILE"
  echo ""
  
  if grep -q "Extracted from Patch" "$ANSWER_FILE"; then
    echo "✅ Test 3 PASSED: Patch extraction worked correctly"
    rm -rf "$TEST_RUN_DIR"
    exit 0
  else
    echo "❌ Test 3 FAILED: Answer doesn't contain expected header"
    rm -rf "$TEST_RUN_DIR"
    exit 1
  fi
else
  echo "❌ Test 3 FAILED: answer.md not created from patch"
  rm -rf "$TEST_RUN_DIR"
  exit 1
fi

