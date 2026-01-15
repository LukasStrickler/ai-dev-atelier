#!/bin/bash
# Tests for resolve-pr-comments skill scripts
# Tests pr-comments-block-hook.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/content/skills/resolve-pr-comments/scripts/pr-comments-block-hook.sh"

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
echo "--- Blocking tests with mocked gh (simulates OPEN PR) ---"
echo ""

MOCK_GH_DIR=$(mktemp -d)
cat > "$MOCK_GH_DIR/gh" << 'MOCK_EOF'
#!/bin/bash
if [[ "$*" == *"--json state"* ]]; then
  echo "OPEN"
  exit 0
fi
exit 1
MOCK_EOF
chmod +x "$MOCK_GH_DIR/gh"

test_hook_mocked() {
  local cmd="$1"
  local expected_exit="$2"
  local expected_pattern="$3"
  local description="$4"
  
  local actual_exit=0
  local output
  output=$(PATH="$MOCK_GH_DIR:$PATH" bash -c "echo '{\"tool_input\":{\"command\":\"$cmd\"}}' | bash '$HOOK_SCRIPT'" 2>&1) || actual_exit=$?
  
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

test_hook_mocked "gh pr view 123 --json comments" 2 "BLOCKED" "Blocks: gh pr view --json comments (mocked OPEN)"
test_hook_mocked "gh pr view 456 --json reviews" 2 "BLOCKED" "Blocks: gh pr view --json reviews (mocked OPEN)"
test_hook_mocked "gh pr view 789 --json comments,reviews" 2 "BLOCKED" "Blocks: gh pr view --json comments,reviews (mocked OPEN)"
test_hook_mocked "gh pr view 123 --json=comments" 2 "BLOCKED" "Blocks: gh pr view --json=comments (equals syntax)"
test_hook_mocked "gh pr view 123 --json=reviews" 2 "BLOCKED" "Blocks: gh pr view --json=reviews (equals syntax)"
test_hook_mocked "gh pr view 123 --comments" 2 "BLOCKED" "Blocks: gh pr view --comments (mocked OPEN)"
test_hook_mocked "gh api repos/$CURRENT_REPO/pulls/123/comments" 2 "BLOCKED" "Blocks: gh api .../pulls/N/comments (mocked OPEN)"
test_hook_mocked "gh api repos/$CURRENT_REPO/pulls/123/reviews" 2 "BLOCKED" "Blocks: gh api .../pulls/N/reviews (mocked OPEN)"
test_hook_mocked "gh api pulls/123/comments" 2 "BLOCKED" "Blocks: gh api pulls/N/comments (relative path)"
test_hook_mocked "gh api pulls/123/reviews" 2 "BLOCKED" "Blocks: gh api pulls/N/reviews (relative path)"

rm -rf "$MOCK_GH_DIR"

echo ""
echo "--- Error message content verification ---"
echo ""

MOCK_GH_DIR2=$(mktemp -d)
cat > "$MOCK_GH_DIR2/gh" << 'MOCK_EOF'
#!/bin/bash
if [[ "$*" == *"--json state"* ]]; then
  echo "OPEN"
  exit 0
fi
exit 1
MOCK_EOF
chmod +x "$MOCK_GH_DIR2/gh"

output=$(PATH="$MOCK_GH_DIR2:$PATH" bash -c "echo '{\"tool_input\":{\"command\":\"gh pr view 123 --json comments\"}}' | bash '$HOOK_SCRIPT'" 2>&1) || true
if echo "$output" | grep -q "resolve-pr-comments"; then
  pass "Error message mentions resolve-pr-comments skill"
else
  fail "Error message should mention resolve-pr-comments skill"
fi

if echo "$output" | grep -q "pr-resolver.sh"; then
  pass "Error message mentions pr-resolver.sh script"
else
  fail "Error message should mention pr-resolver.sh script"
fi

if echo "$output" | grep -q "BYPASS_PR_COMMENTS"; then
  pass "Error message mentions bypass mechanism"
else
  fail "Error message should mention bypass mechanism"
fi

rm -rf "$MOCK_GH_DIR2"

#==============================================================================
# Fork/Upstream Support tests
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: Fork/Upstream Support (--repo parameter)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

UTILS_SCRIPT="$REPO_ROOT/content/skills/resolve-pr-comments/scripts/lib/pr-resolver-utils.sh"

echo ""
echo "--- get_effective_repo tests ---"
echo ""

test_effective_repo() {
  local input="$1"
  local expected_pattern="$2"
  local description="$3"
  
  local result
  result=$(bash -c "source '$UTILS_SCRIPT' && get_effective_repo '$input'" 2>&1)
  local exit_code=$?
  
  if [ "$exit_code" -eq 0 ] && echo "$result" | grep -q "$expected_pattern"; then
    pass "$description"
  else
    fail "$description (got: $result, expected pattern: $expected_pattern)"
  fi
}

test_effective_repo_error() {
  local input="$1"
  local description="$2"
  
  local result exit_code=0
  result=$(bash -c "source '$UTILS_SCRIPT' && get_effective_repo '$input'" 2>&1) || exit_code=$?
  
  if [ "$exit_code" -ne 0 ]; then
    pass "$description"
  else
    fail "$description (expected error, got success: $result)"
  fi
}

test_effective_repo "owner/repo" "owner/repo" "get_effective_repo: explicit repo passed through"
test_effective_repo "upstream-owner/upstream-repo" "upstream-owner/upstream-repo" "get_effective_repo: explicit upstream passed through"
test_effective_repo "my-org/my-project" "my-org/my-project" "get_effective_repo: org/project format works"

test_effective_repo_error "invalid" "get_effective_repo: rejects invalid format (no slash)"
test_effective_repo_error "too/many/slashes" "get_effective_repo: rejects invalid format (too many slashes)"

echo ""
echo "--- --repo parameter parsing tests ---"
echo ""

PR_RESOLVER="$REPO_ROOT/content/skills/resolve-pr-comments/scripts/pr-resolver.sh"
PR_RESOLVE="$REPO_ROOT/content/skills/resolve-pr-comments/scripts/pr-resolver-resolve.sh"
PR_DISMISS="$REPO_ROOT/content/skills/resolve-pr-comments/scripts/pr-resolver-dismiss.sh"

test_script_help() {
  local script="$1"
  local name="$2"
  
  # Check script source for --repo documentation (more reliable than runtime output,
  # which may vary based on auto-detection and conditional display)
  if grep -q "\-\-repo" "$script"; then
    pass "$name: --repo documented in script"
  else
    fail "$name: --repo not documented in script"
  fi
}

test_script_help "$PR_RESOLVER" "pr-resolver.sh"
test_script_help "$PR_RESOLVE" "pr-resolver-resolve.sh"
test_script_help "$PR_DISMISS" "pr-resolver-dismiss.sh"

test_invalid_repo_format() {
  local script="$1"
  local args="$2"
  local name="$3"
  
  local output
  # shellcheck disable=SC2086 # Intentional word splitting for multiple args
  output=$(bash "$script" $args 2>&1 || true)
  local exit_code=$?
  
  if echo "$output" | grep -qi "invalid\|error\|usage"; then
    pass "$name: rejects invalid --repo format"
  else
    fail "$name: should reject invalid --repo format (got: $output)"
  fi
}

test_invalid_repo_format "$PR_RESOLVER" "123 --repo invalid" "pr-resolver.sh"

test_missing_repo_value() {
  local script="$1"
  local args="$2"
  local name="$3"
  
  local output
  # shellcheck disable=SC2086 # Intentional word splitting for multiple args
  output=$(bash "$script" $args 2>&1 || true)
  
  if echo "$output" | grep -qi "requires a value\|error\|usage"; then
    pass "$name: rejects --repo without value"
  else
    fail "$name: should reject --repo without value (got: $output)"
  fi
}

test_missing_repo_value "$PR_RESOLVER" "123 --repo" "pr-resolver.sh"

echo ""
echo "--- Hook fork detection tests ---"
echo ""

MOCK_GH_FORK=$(mktemp -d)
cat > "$MOCK_GH_FORK/gh" << 'MOCK_EOF'
#!/bin/bash
if [[ "$*" == *"--json state"* ]]; then
  echo "OPEN"
  exit 0
fi
if [[ "$*" == *"repo view"*"--json"*"isFork"* ]]; then
  echo "upstream-owner/upstream-repo"
  exit 0
fi
exit 1
MOCK_EOF
chmod +x "$MOCK_GH_FORK/gh"

test_fork_block_message() {
  local cmd="$1"
  local expected_pattern="$2"
  local description="$3"
  
  local output
  output=$(PATH="$MOCK_GH_FORK:$PATH" bash -c "echo '{\"tool_input\":{\"command\":\"$cmd\"}}' | bash '$HOOK_SCRIPT'" 2>&1) || true
  
  if echo "$output" | grep -qi "$expected_pattern"; then
    pass "$description"
  else
    fail "$description (expected pattern: $expected_pattern)"
  fi
}

test_fork_block_message "gh pr view 123 --json comments" "fork\|upstream" "Hook mentions fork/upstream when in fork repo"
test_fork_block_message "gh pr view 123 --json comments" "\-\-repo" "Hook mentions --repo flag when in fork repo"

rm -rf "$MOCK_GH_FORK"

echo ""
echo "--- Hook blocks upstream repo queries when in fork ---"
echo ""

UPSTREAM_REPO="upstream-owner/upstream-repo"

MOCK_GH_FORK2=$(mktemp -d)
cat > "$MOCK_GH_FORK2/gh" << MOCK_EOF2
#!/bin/bash
if [[ "\$*" == *"--json state"* ]]; then
  echo "OPEN"
  exit 0
fi
if [[ "\$*" == *"repo view"*"--json"*"isFork"* ]]; then
  echo "$UPSTREAM_REPO"
  exit 0
fi
exit 1
MOCK_EOF2
chmod +x "$MOCK_GH_FORK2/gh"

test_hook_blocks_upstream() {
  local cmd="$1"
  local expected_exit="$2"
  local description="$3"
  
  local actual_exit=0
  PATH="$MOCK_GH_FORK2:$PATH" bash -c "echo '{\"tool_input\":{\"command\":\"$cmd\"}}' | bash '$HOOK_SCRIPT'" >/dev/null 2>&1 || actual_exit=$?
  
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    pass "$description"
  else
    fail "$description (expected exit $expected_exit, got $actual_exit)"
  fi
}

test_hook_blocks_upstream "gh api repos/$UPSTREAM_REPO/pulls/123/comments" 2 "Blocks: upstream repo PR comments when in fork"
test_hook_blocks_upstream "gh api repos/$UPSTREAM_REPO/pulls/123/reviews" 2 "Blocks: upstream repo PR reviews when in fork"
test_hook_blocks_upstream "gh api repos/other-owner/other-repo/pulls/123/comments" 0 "Allows: unrelated external repo"

rm -rf "$MOCK_GH_FORK2"

#==============================================================================
# pr-wait-for-reviews.sh tests
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: pr-wait-for-reviews.sh (wait/timeout functionality)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WAIT_SCRIPT="$REPO_ROOT/content/skills/resolve-pr-comments/scripts/lib/pr-wait-for-reviews.sh"
CI_FILTERS="$REPO_ROOT/content/skills/resolve-pr-comments/ci-job-filters.txt"

echo ""
echo "--- CI job filters file existence ---"
echo ""

if [ -f "$CI_FILTERS" ]; then
  pass "ci-job-filters.txt exists"
else
  fail "ci-job-filters.txt should exist"
fi

echo ""
echo "--- CI filter patterns include AI bots ---"
echo ""

test_filter_exists() {
  local pattern="$1"
  local description="$2"
  
  if grep -qi "$pattern" "$CI_FILTERS" 2>/dev/null; then
    pass "$description"
  else
    fail "$description (pattern not found: $pattern)"
  fi
}

test_filter_exists "coderabbit" "Filter includes CodeRabbit"
test_filter_exists "copilot" "Filter includes Copilot"
test_filter_exists "cubic" "Filter includes Cubic"
test_filter_exists "gemini" "Filter includes Gemini"

echo ""
echo "--- is_ignored_job function tests ---"
echo ""

test_ignored_job() {
  local job_name="$1"
  local should_ignore="$2"
  local description="$3"
  
  local result=0
  bash -c "
    source '$WAIT_SCRIPT' 2>/dev/null
    is_ignored_job '$job_name' && exit 0 || exit 1
  " 2>/dev/null || result=$?
  
  if [ "$should_ignore" = "yes" ] && [ "$result" -eq 0 ]; then
    pass "$description"
  elif [ "$should_ignore" = "no" ] && [ "$result" -ne 0 ]; then
    pass "$description"
  else
    fail "$description (expected ignore=$should_ignore, got result=$result)"
  fi
}

# Create temp test script with the function
TEMP_TEST=$(mktemp)
cat > "$TEMP_TEST" << 'TESTEOF'
#!/bin/bash
set -euo pipefail
TESTEOF
sed -n '/^load_ci_filters()/,/^wait_for_ci()/p' "$WAIT_SCRIPT" | head -n -1 >> "$TEMP_TEST"
echo "" >> "$TEMP_TEST"
echo "CI_FILTERS_FILE=\"$CI_FILTERS\"" >> "$TEMP_TEST"
echo 'is_ignored_job "$1"' >> "$TEMP_TEST"
chmod +x "$TEMP_TEST"

test_ignored_with_script() {
  local job_name="$1"
  local should_ignore="$2"
  local description="$3"
  
  local result=0
  bash "$TEMP_TEST" "$job_name" 2>/dev/null || result=$?
  
  if [ "$should_ignore" = "yes" ] && [ "$result" -eq 0 ]; then
    pass "$description"
  elif [ "$should_ignore" = "no" ] && [ "$result" -ne 0 ]; then
    pass "$description"
  else
    fail "$description (expected ignore=$should_ignore, got result=$result)"
  fi
}

test_ignored_with_script "CodeRabbit Review" "yes" "Ignores: CodeRabbit Review"
test_ignored_with_script "coderabbit-lint" "yes" "Ignores: coderabbit-lint (lowercase)"
test_ignored_with_script "Copilot code review" "yes" "Ignores: Copilot code review"
test_ignored_with_script "cubic-review" "yes" "Ignores: cubic-review"
test_ignored_with_script "gemini-review" "yes" "Ignores: gemini-review"
test_ignored_with_script "build" "no" "Does not ignore: build"
test_ignored_with_script "test" "no" "Does not ignore: test"
test_ignored_with_script "lint" "no" "Does not ignore: lint"
test_ignored_with_script "deploy" "no" "Does not ignore: deploy"

rm -f "$TEMP_TEST"

echo ""
echo "--- --skip-wait parameter tests ---"
echo ""

test_skip_wait_requires_reason() {
  local output
  output=$(bash "$REPO_ROOT/content/skills/resolve-pr-comments/scripts/pr-resolver.sh" 123 --skip-wait 2>&1 || true)
  
  if echo "$output" | grep -qi "requires.*reason\|reason.*required"; then
    pass "--skip-wait requires a reason"
  else
    fail "--skip-wait should require a reason"
  fi
}

test_skip_wait_logs_reason() {
  local output
  output=$(bash "$REPO_ROOT/content/skills/resolve-pr-comments/scripts/pr-resolver.sh" 99999 --skip-wait "test reason" 2>&1 || true)
  
  if echo "$output" | grep -q "test reason"; then
    pass "--skip-wait logs the provided reason"
  else
    fail "--skip-wait should log the provided reason"
  fi
}

test_skip_wait_requires_reason
test_skip_wait_logs_reason

echo ""
echo "--- SKILL.md timeout documentation ---"
echo ""

SKILL_MD="$REPO_ROOT/content/skills/resolve-pr-comments/SKILL.md"

test_skill_md_timeout() {
  local pattern="$1"
  local description="$2"
  
  if grep -q "$pattern" "$SKILL_MD" 2>/dev/null; then
    pass "$description"
  else
    fail "$description (pattern not found)"
  fi
}

test_skill_md_timeout "timeout.*660000" "SKILL.md documents timeout: 660000"
test_skill_md_timeout "11 min\|11 minute" "SKILL.md mentions 11 minute timeout"
test_skill_md_timeout "REQUIRED\|MUST" "SKILL.md emphasizes timeout is required"

echo ""
echo "--- Wait script argument parsing ---"
echo ""

test_wait_script_arg() {
  local args="$1"
  local expected_exit="$2"
  local description="$3"
  
  local actual_exit=0
  # shellcheck disable=SC2086 # Intentional word splitting
  bash "$WAIT_SCRIPT" $args >/dev/null 2>&1 || actual_exit=$?
  
  # Exit codes: 0=success, 1=CI fail/error, 2=timeout
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    pass "$description"
  else
    fail "$description (expected exit $expected_exit, got $actual_exit)"
  fi
}

test_wait_script_arg "" 1 "Wait script errors without PR number"
test_wait_script_arg "--repo" 1 "Wait script errors with --repo but no value"
test_wait_script_arg "--unknown-flag" 1 "Wait script errors with unknown flag"

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
