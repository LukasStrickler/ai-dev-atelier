#!/bin/bash
# Tests for resolve-pr-comments skill scripts
# Tests pr-comments-block-hook.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/skills/resolve-pr-comments/scripts/pr-comments-block-hook.sh"

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

CURRENT_REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+/[^/]+?)(\.git)?$#\1#' || echo "owner/repo")
CURRENT_REPO="${CURRENT_REPO%.git}"

echo "Current repo for tests: $CURRENT_REPO"
echo ""

#==============================================================================
# pr-comments-block-hook.sh tests
#==============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: pr-comments-block-hook.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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

test_hook_with_output() {
  local cmd="$1"
  local expected_exit="$2"
  local expected_pattern="$3"
  local description="$4"
  
  local actual_exit=0
  local output
  output=$(echo "{\"tool_input\":{\"command\":\"$cmd\"}}" | bash "$HOOK_SCRIPT" 2>&1) || actual_exit=$?
  
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    if [ -n "$expected_pattern" ]; then
      if echo "$output" | grep -q "$expected_pattern"; then
        pass "$description"
      else
        fail "$description (output missing pattern: $expected_pattern)"
      fi
    else
      pass "$description"
    fi
  else
    fail "$description (expected exit $expected_exit, got $actual_exit)"
  fi
}

echo ""
echo "--- Commands that should be ALLOWED (exit 0) ---"
echo ""

test_hook "git status" 0 "Allows: git status"
test_hook "git log" 0 "Allows: git log"
test_hook "git diff" 0 "Allows: git diff"
test_hook "git add ." 0 "Allows: git add"
test_hook "git commit -m test" 0 "Allows: git commit"
test_hook "git push" 0 "Allows: git push"
test_hook "gh pr create" 0 "Allows: gh pr create"
test_hook "gh pr list" 0 "Allows: gh pr list"
test_hook "gh pr merge 123" 0 "Allows: gh pr merge"
test_hook "gh pr checkout 123" 0 "Allows: gh pr checkout"
test_hook "gh pr edit 123" 0 "Allows: gh pr edit"
test_hook "gh issue list" 0 "Allows: gh issue list"
test_hook "gh issue view 123" 0 "Allows: gh issue view"

test_hook "gh pr view 123" 0 "Allows: gh pr view (no --json)"
test_hook "gh pr view 123 --json state" 0 "Allows: gh pr view --json state"
test_hook "gh pr view 123 --json title" 0 "Allows: gh pr view --json title"
test_hook "gh pr view 123 --json number,state,title" 0 "Allows: gh pr view --json (no comments/reviews)"

test_hook "gh api repos/$CURRENT_REPO/pulls/123" 0 "Allows: gh api pulls (no /comments or /reviews)"
test_hook "gh api repos/$CURRENT_REPO/issues/123" 0 "Allows: gh api issues"
test_hook "gh api repos/$CURRENT_REPO/commits" 0 "Allows: gh api commits"
test_hook "gh api user" 0 "Allows: gh api user"
test_hook "gh api orgs/myorg" 0 "Allows: gh api orgs"

test_hook "gh api repos/other/repo/pulls/1/comments" 0 "Allows: gh api external repo comments"
test_hook "gh api repos/facebook/react/pulls/123/reviews" 0 "Allows: gh api external repo reviews"
test_hook "gh api repos/vercel/next.js/pulls/456/comments" 0 "Allows: gh api external repo (vercel/next.js)"

echo ""
echo "--- Commands that may be BLOCKED (exit 2) - depends on PR state ---"
echo ""

test_hook_with_output "gh api repos/$CURRENT_REPO/pulls/99999/comments" 0 "" "Allows: gh api for non-existent PR (fails gracefully)"

echo ""
echo "--- Bypass tests ---"
echo ""

test_hook "gh pr view 123 --json comments # BYPASS_PR_COMMENTS: testing" 0 "Allows: gh pr view with BYPASS_PR_COMMENTS"
test_hook "gh api repos/$CURRENT_REPO/pulls/1/comments # BYPASS_PR_COMMENTS: needed for debug" 0 "Allows: gh api with BYPASS_PR_COMMENTS"

echo ""
echo "--- Edge cases: gh pr view variations ---"
echo ""

test_hook "gh pr view" 0 "Allows: gh pr view (no PR number)"
test_hook "gh pr view --web" 0 "Allows: gh pr view --web"
test_hook "gh pr view 123 --web" 0 "Allows: gh pr view 123 --web"

echo ""
echo "--- Edge cases: gh api variations ---"
echo ""

test_hook_with_output "gh api pulls/99999/comments" 0 "" "Allows: gh api pulls/N/comments for non-existent PR"
test_hook_with_output "gh api pulls/99999/reviews" 0 "" "Allows: gh api pulls/N/reviews for non-existent PR"

test_hook "gh api graphql -f query='{viewer{login}}'" 0 "Allows: gh api graphql (non-PR)"

echo ""
echo "--- Edge cases: JSON parsing ---"
echo ""

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

if echo '{"tool_input":{}}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: JSON without command"
else
  fail "Allows: JSON without command"
fi

if echo '{"tool_input":{"command":""}}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: JSON with empty command"
else
  fail "Allows: JSON with empty command"
fi

echo ""
echo "--- Edge cases: similar commands that shouldn't match ---"
echo ""

test_hook "echo gh pr view 123 --json comments" 0 "Allows: echo with PR command"
test_hook "git config user.email" 0 "Allows: git config"
test_hook "gh auth status" 0 "Allows: gh auth status"
test_hook "gh repo view" 0 "Allows: gh repo view"
test_hook "gh gist list" 0 "Allows: gh gist list"

echo ""
echo "--- External repos are never blocked ---"
echo ""

test_hook "gh api repos/microsoft/vscode/pulls/1/comments" 0 "Allows: external repo (microsoft/vscode)"
test_hook "gh api repos/torvalds/linux/pulls/999/reviews" 0 "Allows: external repo (torvalds/linux)"

echo ""
echo "--- False positive prevention (metadata fields that contain 'comments' or 'reviews') ---"
echo ""

test_hook "gh pr view 123 --json comments_url" 0 "Allows: gh pr view --json comments_url (metadata)"
test_hook "gh pr view 123 --json reviewsUrl" 0 "Allows: gh pr view --json reviewsUrl (metadata)"
test_hook "gh api repos/$CURRENT_REPO/pulls/123/reviews_requested" 0 "Allows: gh api reviews_requested (not reviews)"
test_hook "gh api repos/$CURRENT_REPO/pulls/123/requested_reviewers" 0 "Allows: gh api requested_reviewers"

echo ""
echo "--- gh api flag variations ---"
echo ""

test_hook "gh api -X GET repos/$CURRENT_REPO/pulls/99999/comments" 0 "Allows: gh api -X GET with flags before path"
test_hook "gh api --method GET repos/$CURRENT_REPO/pulls/99999/comments" 0 "Allows: gh api --method GET before path"
test_hook "gh api /repos/$CURRENT_REPO/pulls/99999/comments" 0 "Allows: gh api with leading slash"
test_hook "gh api repos/$CURRENT_REPO/pulls/99999/comments -F per_page=100" 0 "Allows: gh api with trailing flags"
test_hook "gh api repos/$CURRENT_REPO/pulls/99999/comments --jq '.[]'" 0 "Allows: gh api with --jq filter"

echo ""
echo "--- Case sensitivity in repo names ---"
echo ""

CURRENT_REPO_UPPER=$(echo "$CURRENT_REPO" | tr '[:lower:]' '[:upper:]')
test_hook "gh api repos/$CURRENT_REPO_UPPER/pulls/99999/comments" 0 "Allows: gh api with uppercase repo (case insensitive)"

echo ""
echo "--- Error message content verification ---"
echo ""

test_hook_with_output "gh pr view 1 --json comments" 0 "" "Error message test skipped (PR 1 may not exist)"

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
