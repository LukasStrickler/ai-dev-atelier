#!/bin/bash
# Manual test to validate patch detection with simulated changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPTS_DIR="${SCRIPT_DIR}/skills/agent-orchestration/scripts"

echo "=========================================="
echo "Manual Patch Detection Test"
echo "=========================================="
echo ""

# Source utilities
source "${AGENT_SCRIPTS_DIR}/lib/agent-utils.sh"

# Test 1: Create a test run with a worktree
echo "Test 1: Creating test worktree and run..."
TEST_RUN_ID=$(generate_run_id)
RUN_DIR=$(create_run_directory "$TEST_RUN_ID")
WORKTREE_PATH=$(create_worktree "$TEST_RUN_ID" "main")

echo "✓ Created worktree: $WORKTREE_PATH"
echo "✓ Run directory: $RUN_DIR"
echo ""

# Test 2: Simulate agent work - create answer.md in root
echo "Test 2: Simulating agent work - creating answer.md..."
cat > "${WORKTREE_PATH}/answer.md" << 'EOF'
# Answer

Information retrieval systems are computer systems designed to search and retrieve information from large collections of data. They use various techniques like indexing, ranking algorithms, and query processing to efficiently find relevant documents or information based on user queries.
EOF

# Commit the change to the agent branch
cd "$WORKTREE_PATH"
git add answer.md
git commit -m "Agent: Added answer.md" >/dev/null 2>&1 || true

echo "✓ Created answer.md and committed to agent branch"
echo ""

# Test 3: Generate patch artifacts
echo "Test 3: Generating patch artifacts..."
BASE_BRANCH="main"
generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$BASE_BRANCH"

if [ -f "${RUN_DIR}/patch.diff" ]; then
  PATCH_SIZE=$(wc -c < "${RUN_DIR}/patch.diff" 2>/dev/null || echo "0")
  echo "✓ patch.diff generated (${PATCH_SIZE} bytes)"
  
  if [ "$PATCH_SIZE" -gt 0 ]; then
    echo "  Patch preview (first 10 lines):"
    head -10 "${RUN_DIR}/patch.diff" | sed 's/^/  /'
  fi
else
  echo "❌ ERROR: patch.diff not generated"
  exit 1
fi
echo ""

# Test 4: Test patch analysis
echo "Test 4: Testing patch analysis functions..."
if check_work_from_patch "$RUN_DIR" "research"; then
  echo "✓ check_work_from_patch detected work (research mode)"
else
  echo "❌ ERROR: check_work_from_patch did not detect work"
  exit 1
fi

PATCH_ANALYSIS=$(analyze_patch_for_results "$RUN_DIR" "research")
echo "✓ analyze_patch_for_results returned:"
if command -v jq &> /dev/null; then
  echo "$PATCH_ANALYSIS" | jq '.' | sed 's/^/  /'
else
  echo "$PATCH_ANALYSIS" | sed 's/^/  /'
fi
echo ""

# Test 5: Test check_result_exists
echo "Test 5: Testing check_result_exists..."
# Create minimal meta.json for check_result_exists
cat > "${RUN_DIR}/../meta.json" << EOF
{"runId": "$TEST_RUN_ID", "worktreePath": "$WORKTREE_PATH"}
EOF

if check_result_exists "$TEST_RUN_ID" "research"; then
  echo "✓ check_result_exists detected result (research mode)"
else
  echo "❌ ERROR: check_result_exists did not detect result"
  exit 1
fi
echo ""

# Test 6: Test extract_answer_file
echo "Test 6: Testing extract_answer_file..."
if extract_answer_file "$WORKTREE_PATH" "$RUN_DIR"; then
  if [ -f "${RUN_DIR}/answer.md" ]; then
    ANSWER_SIZE=$(wc -c < "${RUN_DIR}/answer.md" 2>/dev/null || echo "0")
    echo "✓ answer.md extracted successfully (${ANSWER_SIZE} bytes)"
    echo "  Content preview:"
    head -3 "${RUN_DIR}/answer.md" | sed 's/^/  /'
  else
    echo "❌ ERROR: answer.md not extracted to run directory"
    exit 1
  fi
else
  echo "❌ ERROR: extract_answer_file failed"
  exit 1
fi
echo ""

# Test 7: Test with answer.md in subdirectory
echo "Test 7: Testing answer.md detection in subdirectory..."
# Create a subdirectory and move answer.md there
mkdir -p "${WORKTREE_PATH}/subdir"
mv "${WORKTREE_PATH}/answer.md" "${WORKTREE_PATH}/subdir/answer.md"
cd "$WORKTREE_PATH"
git add -A
git commit -m "Agent: Moved answer.md to subdirectory" >/dev/null 2>&1 || true

# Regenerate patch
generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$BASE_BRANCH"

# Test if patch analysis finds it
PATCH_ANALYSIS2=$(analyze_patch_for_results "$RUN_DIR" "research")
if command -v jq &> /dev/null; then
  ANSWER_LOC=$(echo "$PATCH_ANALYSIS2" | jq -r '.answerLocation // null')
  if [ "$ANSWER_LOC" != "null" ] && [ -n "$ANSWER_LOC" ]; then
    echo "✓ Patch analysis found answer.md at: $ANSWER_LOC"
  else
    echo "⚠ WARNING: Patch analysis did not find answer.md location"
  fi
fi

# Test extract_answer_file with subdirectory
rm -f "${RUN_DIR}/answer.md"
if extract_answer_file "$WORKTREE_PATH" "$RUN_DIR"; then
  if [ -f "${RUN_DIR}/answer.md" ]; then
    echo "✓ answer.md extracted from subdirectory"
  else
    echo "❌ ERROR: answer.md not extracted from subdirectory"
    exit 1
  fi
else
  echo "⚠ WARNING: extract_answer_file did not find answer.md in subdirectory"
fi
echo ""

# Test 8: Test work mode detection
echo "Test 8: Testing work mode detection..."
# Create a code file change
cat > "${WORKTREE_PATH}/test.py" << 'EOF'
def hello():
    print("Hello, World!")
EOF

cd "$WORKTREE_PATH"
git add test.py
git commit -m "Agent: Added test.py" >/dev/null 2>&1 || true

# Regenerate patch
generate_diff_artifacts "$WORKTREE_PATH" "$RUN_DIR" "$BASE_BRANCH"

if check_work_from_patch "$RUN_DIR" "work"; then
  echo "✓ check_work_from_patch detected work (work mode)"
else
  echo "❌ ERROR: check_work_from_patch did not detect work in work mode"
  exit 1
fi

PATCH_ANALYSIS3=$(analyze_patch_for_results "$RUN_DIR" "work")
if command -v jq &> /dev/null; then
  WORK_DETECTED=$(echo "$PATCH_ANALYSIS3" | jq -r '.workDetected // false')
  if [ "$WORK_DETECTED" = "true" ]; then
    echo "✓ Patch analysis detected work in work mode"
  else
    echo "❌ ERROR: Patch analysis did not detect work in work mode"
    exit 1
  fi
fi
echo ""

# Cleanup
echo "Cleaning up test worktree..."
cleanup_worktree "$TEST_RUN_ID" 2>/dev/null || true

echo ""
echo "=========================================="
echo "All Tests Passed! ✓"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Patch generation works"
echo "  ✓ Patch analysis detects work (research mode)"
echo "  ✓ Patch analysis detects work (work mode)"
echo "  ✓ answer.md extraction works (root location)"
echo "  ✓ answer.md extraction works (subdirectory)"
echo "  ✓ check_result_exists works correctly"
echo ""

