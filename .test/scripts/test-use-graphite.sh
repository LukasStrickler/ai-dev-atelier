#!/bin/bash
# Tests for use-graphite skill scripts
# Tests graphite-detect.sh and graphite-block-hook.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DETECT_SCRIPT="$REPO_ROOT/skills/use-graphite/scripts/graphite-detect.sh"
HOOK_SCRIPT="$REPO_ROOT/skills/use-graphite/scripts/graphite-block-hook.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Create temp directory for isolated tests
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

#==============================================================================
# graphite-block-hook.sh tests
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: graphite-block-hook.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Helper to test hook
test_hook() {
  local cmd="$1"
  local expected_exit="$2"
  local description="$3"
  
  local actual_exit=0
  echo "{\"tool_input\":{\"command\":\"$cmd\"}}" | bash "$HOOK_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    pass "$description"
  else
    fail "$description (expected exit $expected_exit, got $actual_exit)"
  fi
}

# Commands that should be BLOCKED (exit 2) in a Graphite repo
test_hook "git push" 2 "Blocks: git push"
test_hook "git push origin main" 2 "Blocks: git push origin main"
test_hook "git push -u origin feature" 2 "Blocks: git push -u origin feature"
test_hook "gh pr create" 2 "Blocks: gh pr create"
test_hook "gh pr create --title foo" 2 "Blocks: gh pr create with args"
test_hook "git checkout -b new-branch" 2 "Blocks: git checkout -b"
test_hook "git checkout --branch new-branch" 2 "Blocks: git checkout --branch"
test_hook "git switch -c new-branch" 2 "Blocks: git switch -c"
test_hook "git rebase main" 2 "Blocks: git rebase (non-interactive)"
test_hook "git rebase origin/main" 2 "Blocks: git rebase origin/main"
test_hook "git branch new-feature" 2 "Blocks: git branch <name> (create)"

# Commands that should be ALLOWED (exit 0)
test_hook "git status" 0 "Allows: git status"
test_hook "git log" 0 "Allows: git log"
test_hook "git diff" 0 "Allows: git diff"
test_hook "git add ." 0 "Allows: git add"
test_hook "git commit -m test" 0 "Allows: git commit"
test_hook "git fetch" 0 "Allows: git fetch"
test_hook "git pull" 0 "Allows: git pull"
test_hook "git stash" 0 "Allows: git stash"
test_hook "git merge feature" 0 "Allows: git merge"
test_hook "git cherry-pick abc123" 0 "Allows: git cherry-pick"

# Interactive rebase should be ALLOWED (exit 0)
test_hook "git rebase -i main" 0 "Allows: git rebase -i main"
test_hook "git rebase --interactive main" 0 "Allows: git rebase --interactive main"
test_hook "git rebase main -i" 0 "Allows: git rebase main -i (flag after branch)"
test_hook "git rebase -i --autosquash main" 0 "Allows: git rebase -i with extra flags"

# Branch operations that should be ALLOWED
test_hook "git branch -d old-branch" 0 "Allows: git branch -d (delete)"
test_hook "git branch -D old-branch" 0 "Allows: git branch -D (force delete)"
test_hook "git branch --delete old-branch" 0 "Allows: git branch --delete"
test_hook "git branch -l" 0 "Allows: git branch -l (list)"
test_hook "git branch --list" 0 "Allows: git branch --list"
test_hook "git branch -a" 0 "Allows: git branch -a (all)"
test_hook "git branch -r" 0 "Allows: git branch -r (remotes)"
test_hook "git branch -v" 0 "Allows: git branch -v (verbose)"

# Bypass should ALLOW blocked commands
test_hook "git push # BYPASS_GRAPHITE: testing" 0 "Allows: git push with BYPASS_GRAPHITE"
test_hook "gh pr create # BYPASS_GRAPHITE: emergency" 0 "Allows: gh pr create with BYPASS_GRAPHITE"

# Empty/malformed input should be ALLOWED (fail open)
echo "" | bash "$HOOK_SCRIPT" >/dev/null 2>&1 && pass "Allows: empty stdin" || fail "Allows: empty stdin"
echo "{}" | bash "$HOOK_SCRIPT" >/dev/null 2>&1 && pass "Allows: empty JSON" || fail "Allows: empty JSON"
echo "not json" | bash "$HOOK_SCRIPT" >/dev/null 2>&1 && pass "Allows: invalid JSON" || fail "Allows: invalid JSON"

#==============================================================================
# graphite-detect.sh tests (in current repo - should be Graphite-enabled)
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: graphite-detect.sh (current repo)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test in current repo (should be Graphite-enabled based on earlier test)
cd "$REPO_ROOT"
output=$(bash "$DETECT_SCRIPT" 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  pass "graphite-detect.sh exits 0 in Graphite repo"
else
  fail "graphite-detect.sh should exit 0 in Graphite repo (got $exit_code)"
fi

if echo "$output" | grep -q '"enabled":true'; then
  pass "graphite-detect.sh returns enabled:true"
else
  fail "graphite-detect.sh should return enabled:true"
fi

if echo "$output" | grep -q '"trunk"'; then
  pass "graphite-detect.sh includes trunk branch"
else
  fail "graphite-detect.sh should include trunk branch"
fi

if echo "$output" | grep -q '"config"'; then
  pass "graphite-detect.sh includes config path"
else
  fail "graphite-detect.sh should include config path"
fi

#==============================================================================
# graphite-detect.sh tests (non-git directory)
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: graphite-detect.sh (non-git directory)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$TMP_DIR"
output=$(bash "$DETECT_SCRIPT" 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 1 ]; then
  pass "graphite-detect.sh exits 1 in non-git dir"
else
  fail "graphite-detect.sh should exit 1 in non-git dir (got $exit_code)"
fi

if echo "$output" | grep -q '"enabled":false'; then
  pass "graphite-detect.sh returns enabled:false"
else
  fail "graphite-detect.sh should return enabled:false"
fi

#==============================================================================
# graphite-detect.sh tests (git repo without Graphite)
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: graphite-detect.sh (git repo without Graphite config)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

NON_GT_REPO="$TMP_DIR/non-graphite-repo"
mkdir -p "$NON_GT_REPO"
cd "$NON_GT_REPO"
git init -q

output=$(bash "$DETECT_SCRIPT" 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" -eq 1 ]; then
  pass "graphite-detect.sh exits 1 in git repo without Graphite"
else
  fail "graphite-detect.sh should exit 1 without Graphite config (got $exit_code)"
fi

if echo "$output" | grep -q 'not initialized with Graphite\|enabled.*false'; then
  pass "graphite-detect.sh indicates Graphite not initialized"
else
  fail "graphite-detect.sh should indicate Graphite not initialized"
fi

#==============================================================================
# Summary
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "❌ Some tests failed!"
  exit 1
else
  echo "✅ All tests passed!"
  exit 0
fi
