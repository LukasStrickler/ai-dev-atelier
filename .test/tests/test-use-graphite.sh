#!/bin/bash
# Tests for use-graphite skill scripts
# Tests graphite-detect.sh and graphite-block-hook.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DETECT_SCRIPT="$REPO_ROOT/content/skills/use-graphite/scripts/graphite-detect.sh"
HOOK_SCRIPT="$REPO_ROOT/content/skills/use-graphite/scripts/graphite-block-hook.sh"

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
test_hook "git checkout -bnew-branch" 2 "Blocks: git checkout -b (no space)"
test_hook "git checkout --branch new-branch" 2 "Blocks: git checkout --branch"
test_hook "git switch -c new-branch" 2 "Blocks: git switch -c"
test_hook "git switch -cnew-branch" 2 "Blocks: git switch -c (no space)"
test_hook "git switch --create new-branch" 2 "Blocks: git switch --create"
test_hook "git rebase main" 2 "Blocks: git rebase (non-interactive)"
test_hook "git rebase origin/main" 2 "Blocks: git rebase origin/main"
test_hook "git rebase" 2 "Blocks: git rebase (no args)"
test_hook "git branch new-feature" 2 "Blocks: git branch <name> (create)"
test_hook "git branch -c old new" 2 "Blocks: git branch -c (copy)"
test_hook "git branch --copy old new" 2 "Blocks: git branch --copy"
test_hook "git branch -t new origin/main" 2 "Blocks: git branch -t (track)"
test_hook "git branch --track new origin/main" 2 "Blocks: git branch --track"
test_hook "git branch --no-track new origin/main" 2 "Blocks: git branch --no-track"
test_hook "git branch -f existing HEAD~1" 2 "Blocks: git branch -f (force)"
test_hook "git branch --force existing HEAD" 2 "Blocks: git branch --force"

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
test_hook "git branch -m old new" 0 "Allows: git branch -m (rename)"
test_hook "git branch -M old new" 0 "Allows: git branch -M (force rename)"
test_hook "git branch --move old new" 0 "Allows: git branch --move"
test_hook "git branch -av" 0 "Allows: git branch -av (combined flags)"
test_hook "git branch -vv" 0 "Allows: git branch -vv (very verbose)"
test_hook "git branch --show-current" 0 "Allows: git branch --show-current"

# Bypass should ALLOW blocked commands
test_hook "git push # BYPASS_GRAPHITE: testing" 0 "Allows: git push with BYPASS_GRAPHITE"
test_hook "gh pr create # BYPASS_GRAPHITE: emergency" 0 "Allows: gh pr create with BYPASS_GRAPHITE"
test_hook "git checkout -b feat # BYPASS_GRAPHITE: reason" 0 "Allows: git checkout -b with BYPASS"
test_hook "git rebase main # BYPASS_GRAPHITE: needed" 0 "Allows: git rebase with BYPASS"

# Edge cases: git push variations
test_hook "git push --force" 2 "Blocks: git push --force"
test_hook "git push -f" 2 "Blocks: git push -f"
test_hook "git push --force-with-lease" 2 "Blocks: git push --force-with-lease"
test_hook "git push -u origin HEAD" 2 "Blocks: git push -u origin HEAD"
test_hook "git push --set-upstream origin feat" 2 "Blocks: git push --set-upstream"
test_hook "git push origin HEAD:refs/for/main" 2 "Blocks: git push with refspec"
test_hook "git push --tags" 2 "Blocks: git push --tags"
test_hook "git push origin --delete branch" 2 "Blocks: git push origin --delete"

# Edge cases: gh pr variations  
test_hook "gh pr create -t title -b body" 2 "Blocks: gh pr create with short flags"
test_hook "gh pr create --draft" 2 "Blocks: gh pr create --draft"
test_hook "gh pr create --web" 2 "Blocks: gh pr create --web"
test_hook "gh pr view" 0 "Allows: gh pr view"
test_hook "gh pr list" 0 "Allows: gh pr list"
test_hook "gh pr merge" 0 "Allows: gh pr merge"
test_hook "gh pr checkout 123" 0 "Allows: gh pr checkout"
test_hook "gh pr edit 123" 0 "Allows: gh pr edit"

# Edge cases: git checkout variations
test_hook "git checkout main" 0 "Allows: git checkout main (switch branch)"
test_hook "git checkout -" 0 "Allows: git checkout - (previous branch)"
test_hook "git checkout HEAD~1" 0 "Allows: git checkout HEAD~1"
test_hook "git checkout -- file.txt" 0 "Allows: git checkout -- file.txt"
test_hook "git checkout -B existing-branch" 2 "Blocks: git checkout -B (force create)"
test_hook "git checkout -Bnew-branch" 2 "Blocks: git checkout -B (no space)"
test_hook "git checkout --orphan new" 0 "Allows: git checkout --orphan"
test_hook "git checkout -t origin/feat" 0 "Allows: git checkout -t (track)"

# Edge cases: git switch variations
test_hook "git switch main" 0 "Allows: git switch main"
test_hook "git switch -" 0 "Allows: git switch -"
test_hook "git switch --detach HEAD" 0 "Allows: git switch --detach"
test_hook "git switch -C existing" 2 "Blocks: git switch -C (force create)"
test_hook "git switch --force-create new" 2 "Blocks: git switch --force-create"

# Edge cases: git rebase variations
test_hook "git rebase --onto main feat" 2 "Blocks: git rebase --onto"
test_hook "git rebase --continue" 0 "Allows: git rebase --continue"
test_hook "git rebase --abort" 0 "Allows: git rebase --abort"
test_hook "git rebase --skip" 0 "Allows: git rebase --skip"
test_hook "git rebase --quit" 0 "Allows: git rebase --quit"
test_hook "git rebase HEAD~3 -i" 0 "Allows: git rebase HEAD~3 -i"
test_hook "git rebase -i HEAD~5" 0 "Allows: git rebase -i HEAD~5"
test_hook "git rebase --interactive --autosquash main" 0 "Allows: git rebase --interactive --autosquash"

# Edge cases: git branch variations
test_hook "git branch" 0 "Allows: git branch (no args, lists)"
test_hook "git branch --contains abc123" 0 "Allows: git branch --contains"
test_hook "git branch --merged" 0 "Allows: git branch --merged"
test_hook "git branch --no-merged" 0 "Allows: git branch --no-merged"
test_hook "git branch --set-upstream-to=origin/main" 0 "Allows: git branch --set-upstream-to"
test_hook "git branch -u origin/main" 0 "Allows: git branch -u (set upstream)"
test_hook "git branch --unset-upstream" 0 "Allows: git branch --unset-upstream"
test_hook "git branch --edit-description" 0 "Allows: git branch --edit-description"
test_hook "git branch --sort=-committerdate" 0 "Allows: git branch --sort"

# Edge cases: commands that look similar but shouldn't match
test_hook "git pushing" 0 "Allows: git pushing (not a real command)"
test_hook "git pusher" 0 "Allows: git pusher (not a real command)"
test_hook "git checkout-index" 0 "Allows: git checkout-index"
test_hook "git branch-filter" 0 "Allows: git branch-filter (not matched)"
test_hook "echo git push" 0 "Allows: echo git push"
test_hook "git config push.default" 0 "Allows: git config push.default"

# Edge cases: JSON parsing
test_hook "git commit -m \"test message\"" 0 "Allows: git commit with quoted message"

# Graphite commands should NEVER be blocked (sanity check)
test_hook "gt create new-branch" 0 "Allows: gt create (Graphite command)"
test_hook "gt submit" 0 "Allows: gt submit (Graphite command)"
test_hook "gt restack" 0 "Allows: gt restack (Graphite command)"
test_hook "gt sync" 0 "Allows: gt sync (Graphite command)"

# Empty/malformed input should be ALLOWED (fail open)
if echo "" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: empty stdin"
else
  fail "Allows: empty stdin"
fi
if echo "{}" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: empty JSON"
else
  fail "Allows: empty JSON"
fi
if echo "not json" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: invalid JSON"
else
  fail "Allows: invalid JSON"
fi

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
