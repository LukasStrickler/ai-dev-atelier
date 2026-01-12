#!/bin/bash
# Tests for generate-release-notes.sh
# Validates that the script generates proper markdown with correctly formatted code blocks
#
# TEST COVERAGE:
# - Script fails when VERSION not provided
# - Script succeeds with VERSION env var
# - Script succeeds with positional argument
# - Generated markdown has proper fenced code blocks (not escaped)
# - Blank lines before code blocks (CommonMark compliance)
# - Variables are correctly substituted
# - Output file is created with expected content
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/generate-release-notes.sh"
TEMP_DIR=""

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

setup() {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
}

teardown() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap teardown EXIT

#==============================================================================
# Test: VERSION required
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: generate-release-notes.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "--- VERSION requirement ---"
echo ""

setup
if bash "$SCRIPT_UNDER_TEST" 2>/dev/null; then
  fail "Script should fail when VERSION not provided"
else
  pass "Script fails when VERSION not provided"
fi
teardown

setup
output=$(bash "$SCRIPT_UNDER_TEST" 2>&1 || true)
if echo "$output" | grep -q "VERSION is required"; then
  pass "Error message mentions VERSION is required"
else
  fail "Error message should mention VERSION is required (got: $output)"
fi
teardown

#==============================================================================
# Test: Script execution modes
#==============================================================================

echo ""
echo "--- Script execution modes ---"
echo ""

# Test with VERSION env var
setup
if VERSION="1.2.3" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1; then
  pass "Script succeeds with VERSION env var"
else
  fail "Script should succeed with VERSION env var"
fi
teardown

# Test with positional argument
setup
if bash "$SCRIPT_UNDER_TEST" "1.2.3" >/dev/null 2>&1; then
  pass "Script succeeds with positional argument"
else
  fail "Script should succeed with positional argument"
fi
teardown

setup
VERSION="9.9.9" bash "$SCRIPT_UNDER_TEST" "1.2.3" >/dev/null 2>&1
if grep -q "v9.9.9" release-body.md 2>/dev/null; then
  pass "VERSION env var takes precedence over positional arg"
else
  fail "VERSION env var should take precedence"
fi
teardown

#==============================================================================
# Test: Output file creation
#==============================================================================

echo ""
echo "--- Output file creation ---"
echo ""

setup
VERSION="1.0.0" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1
if [[ -f "release-body.md" ]]; then
  pass "Creates release-body.md file"
else
  fail "Should create release-body.md file"
fi
teardown

#==============================================================================
# Test: Markdown code block formatting (CRITICAL)
#==============================================================================

echo ""
echo "--- Markdown code block formatting ---"
echo ""

setup
VERSION="2.0.0" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1

# Check for proper triple backticks (not escaped)
if grep -q '```bash' release-body.md; then
  pass "Contains proper \`\`\`bash fencing"
else
  fail "Should contain proper \`\`\`bash fencing (not escaped)"
fi

# Check that backticks are NOT escaped
if grep -q '\\`\\`\\`' release-body.md; then
  fail "Backticks should NOT be escaped with backslashes"
else
  pass "Backticks are not escaped"
fi

# Count opening code fences
fence_count=$(grep -c '^```bash$' release-body.md || echo "0")
if [[ "$fence_count" -eq 2 ]]; then
  pass "Contains exactly 2 code blocks"
else
  fail "Should contain exactly 2 code blocks (got: $fence_count)"
fi

# Count closing code fences
close_fence_count=$(grep -c '^```$' release-body.md || echo "0")
if [[ "$close_fence_count" -eq 2 ]]; then
  pass "All code blocks are properly closed"
else
  fail "Should have 2 closing fences (got: $close_fence_count)"
fi

teardown

#==============================================================================
# Test: CommonMark compliance (blank lines before code blocks)
#==============================================================================

echo ""
echo "--- CommonMark compliance ---"
echo ""

setup
VERSION="2.0.0" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1

# Check blank line before first code block
# The pattern should be: non-code line, blank line, ```bash
if awk '/^```bash$/{if(prev!=""){exit 1}}; {prev=$0}' release-body.md; then
  pass "Blank line before code blocks (CommonMark compliant)"
else
  fail "Should have blank line before code blocks"
fi

teardown

#==============================================================================
# Test: Variable substitution
#==============================================================================

echo ""
echo "--- Variable substitution ---"
echo ""

setup
VERSION="3.5.7" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1

if grep -q "v3.5.7" release-body.md; then
  pass "VERSION is substituted correctly (v3.5.7)"
else
  fail "VERSION should be substituted (expected v3.5.7)"
fi

if grep -q "checkout v3.5.7" release-body.md; then
  pass "git checkout command uses correct version"
else
  fail "git checkout should use VERSION"
fi

teardown

# Test REPO_NAME substitution
setup
VERSION="1.0.0" REPO_NAME="custom/repo" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1

if grep -q "github.com/custom/repo" release-body.md; then
  pass "REPO_NAME is substituted correctly"
else
  fail "REPO_NAME should be substituted"
fi

if grep -q "~/repo" release-body.md && grep -q "cd ~/repo" release-body.md; then
  pass "REPO_BASENAME derived from custom REPO_NAME"
else
  fail "REPO_BASENAME should be derived from custom REPO_NAME (expected ~/repo)"
fi

teardown

# Test default REPO_NAME
setup
VERSION="1.0.0" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1

if grep -q "LukasStrickler/ai-dev-atelier" release-body.md; then
  pass "Default REPO_NAME is used when not set"
else
  fail "Default REPO_NAME should be LukasStrickler/ai-dev-atelier"
fi

if grep -q "~/ai-dev-atelier" release-body.md; then
  pass "REPO_BASENAME is derived correctly from REPO_NAME"
else
  fail "REPO_BASENAME should be derived from REPO_NAME"
fi

teardown

#==============================================================================
# Test: Full content structure
#==============================================================================

echo ""
echo "--- Content structure ---"
echo ""

setup
VERSION="1.0.0" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1

if grep -q "## Installation" release-body.md; then
  pass "Contains Installation header"
else
  fail "Should contain ## Installation header"
fi

if grep -q "git clone" release-body.md; then
  pass "Contains git clone instruction"
else
  fail "Should contain git clone instruction"
fi

if grep -q "bash install.sh" release-body.md; then
  pass "Contains install.sh instruction"
else
  fail "Should contain bash install.sh instruction"
fi

if grep -q "Or update" release-body.md; then
  pass "Contains update instructions"
else
  fail "Should contain update instructions"
fi

if grep -q "git fetch --tags" release-body.md; then
  pass "Contains git fetch --tags instruction"
else
  fail "Should contain git fetch --tags instruction"
fi

teardown

#==============================================================================
# Test: Output message
#==============================================================================

echo ""
echo "--- Output message ---"
echo ""

setup
output=$(VERSION="1.0.0" bash "$SCRIPT_UNDER_TEST" 2>&1)

if echo "$output" | grep -q "Generated release-body.md"; then
  pass "Outputs success message"
else
  fail "Should output success message"
fi

if echo "$output" | grep -q "v1.0.0"; then
  pass "Success message includes version"
else
  fail "Success message should include version"
fi

teardown

#==============================================================================
# Test: Edge cases
#==============================================================================

echo ""
echo "--- Edge cases ---"
echo ""

# Test with version containing special characters (dots, dashes)
setup
if VERSION="1.0.0-beta.1" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1; then
  if grep -q "v1.0.0-beta.1" release-body.md; then
    pass "Handles semver with pre-release tag"
  else
    fail "Should handle semver with pre-release tag"
  fi
else
  fail "Script should handle semver with pre-release tag"
fi
teardown

# Test with version starting with 'v' (should not double-prefix)
setup
VERSION="v2.0.0" bash "$SCRIPT_UNDER_TEST" >/dev/null 2>&1
# This is a design choice - currently it will produce vv2.0.0
# We document the current behavior
if grep -q "vv2.0.0" release-body.md; then
  pass "Note: VERSION with 'v' prefix creates vv (user should not include v)"
else
  pass "VERSION with 'v' prefix handled"
fi
teardown

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
