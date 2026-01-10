#!/bin/bash
# Tests for release-block-hook.sh
# Comprehensive test suite ensuring releases cannot be triggered by AI agents
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/.hooks/release-block-hook.sh"

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

test_hook() {
  local cmd="$1"
  local expected_exit="$2"
  local description="$3"
  
  local actual_exit=0
  jq -n --arg c "$cmd" '{"tool_input":{"command":$c}}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1 || actual_exit=$?
  
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
  output=$(jq -n --arg c "$cmd" '{"tool_input":{"command":$c}}' | bash "$HOOK_SCRIPT" 2>&1) || actual_exit=$?
  
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

#==============================================================================
# release-block-hook.sh tests
#==============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: release-block-hook.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "--- Core: gh workflow run release.yml (should be BLOCKED) ---"
echo ""

test_hook "gh workflow run release.yml" 2 "Blocks: gh workflow run release.yml"
test_hook "gh workflow run release.yml -f version=1.0.0" 2 "Blocks: with -f version flag"
test_hook "gh workflow run release.yml -f version=1.0.0 -f dry_run=true" 2 "Blocks: with multiple -f flags"
test_hook "gh workflow run release.yml --ref main" 2 "Blocks: with --ref flag"
test_hook "gh workflow run release.yml -R owner/repo" 2 "Blocks: with -R repo flag"
test_hook "gh workflow run release.yml --repo owner/repo" 2 "Blocks: with --repo flag"
test_hook "gh workflow run .github/workflows/release.yml" 2 "Blocks: with full path"
test_hook "gh workflow run ./release.yml" 2 "Blocks: with ./ prefix"
test_hook "gh workflow run workflows/release.yml" 2 "Blocks: with workflows/ prefix"

echo ""
echo "--- Core: gh workflow run Release (display name, should be BLOCKED) ---"
echo ""

test_hook "gh workflow run Release" 2 "Blocks: gh workflow run Release (display name)"
test_hook "gh workflow run Release -f version=1.0.0" 2 "Blocks: Release with -f flag"
test_hook "gh workflow run 'Release'" 2 "Blocks: 'Release' (single quoted)"
test_hook "gh workflow run \"Release\"" 2 "Blocks: \"Release\" (double quoted)"
test_hook "gh workflow run Release --ref main" 2 "Blocks: Release with --ref"
test_hook "gh workflow run Release -R owner/repo" 2 "Blocks: Release with -R"

echo ""
echo "--- Core: gh release create (should be BLOCKED) ---"
echo ""

test_hook "gh release create v1.0.0" 2 "Blocks: gh release create v1.0.0"
test_hook "gh release create" 2 "Blocks: gh release create (no args)"
test_hook "gh release create v1.0.0 --title Release" 2 "Blocks: with --title"
test_hook "gh release create v1.0.0 --notes notes" 2 "Blocks: with --notes"
test_hook "gh release create v1.0.0 --notes-file file.md" 2 "Blocks: with --notes-file"
test_hook "gh release create v1.0.0 --generate-notes" 2 "Blocks: with --generate-notes"
test_hook "gh release create v1.0.0 --draft" 2 "Blocks: with --draft"
test_hook "gh release create v1.0.0 --prerelease" 2 "Blocks: with --prerelease"
test_hook "gh release create v1.0.0 --latest" 2 "Blocks: with --latest"
test_hook "gh release create v1.0.0 -R owner/repo" 2 "Blocks: with -R repo"
test_hook "gh release create v1.0.0 --repo owner/repo" 2 "Blocks: with --repo"
test_hook "gh release create v1.0.0 --target main" 2 "Blocks: with --target"
test_hook "gh release create v1.0.0 file1.zip file2.tar.gz" 2 "Blocks: with asset files"

echo ""
echo "--- Word boundary: pre-release.yml and similar should NOT be blocked ---"
echo ""

test_hook "gh workflow run pre-release.yml" 0 "Allows: pre-release.yml (not release.yml)"
test_hook "gh workflow run pre-release.yml -f version=1.0.0" 0 "Allows: pre-release.yml with flags"
test_hook "gh workflow run some-release.yml" 0 "Allows: some-release.yml"
test_hook "gh workflow run release.yml.bak" 0 "Allows: release.yml.bak (word boundary)"
test_hook "gh workflow run release.yaml" 0 "Allows: release.yaml (different extension)"
test_hook "gh workflow run release-workflow.yml" 0 "Allows: release-workflow.yml"
test_hook "gh workflow run myrelease.yml" 0 "Allows: myrelease.yml"
test_hook "gh workflow run release_v2.yml" 0 "Allows: release_v2.yml"
test_hook "gh workflow run releases.yml" 0 "Allows: releases.yml (plural)"
test_hook "gh workflow run auto-release.yml" 0 "Allows: auto-release.yml"

echo ""
echo "--- Word boundary: Release display name edge cases ---"
echo ""

test_hook "gh workflow run Pre-Release" 0 "Allows: Pre-Release (not Release)"
test_hook "gh workflow run AutoRelease" 0 "Allows: AutoRelease"
test_hook "gh workflow run release-pipeline" 0 "Allows: release-pipeline"
test_hook "gh workflow run ReleaseCanary" 0 "Allows: ReleaseCanary"
test_hook "gh workflow run MyRelease" 0 "Allows: MyRelease"

echo ""
echo "--- Command prefixes that should still be BLOCKED ---"
echo ""

test_hook "export CI=true && gh workflow run release.yml" 2 "Blocks: export prefix"
test_hook "export CI=true; gh workflow run release.yml" 2 "Blocks: export with semicolon"
test_hook "CI=true gh workflow run release.yml" 2 "Blocks: inline env var"
test_hook "CI=true FORCE=1 gh workflow run release.yml" 2 "Blocks: multiple inline env vars"
test_hook "env CI=true gh workflow run release.yml" 2 "Blocks: env command prefix"
test_hook "bash -c 'gh workflow run release.yml'" 2 "Blocks: bash -c wrapper"
test_hook "sh -c 'gh workflow run release.yml'" 2 "Blocks: sh -c wrapper"
test_hook "/bin/bash -c 'gh workflow run release.yml'" 2 "Blocks: full path bash"
test_hook "eval 'gh workflow run release.yml'" 2 "Blocks: eval wrapper"
test_hook "time gh workflow run release.yml" 2 "Blocks: time prefix"
test_hook "nohup gh workflow run release.yml" 2 "Blocks: nohup prefix"
test_hook "nice gh workflow run release.yml" 2 "Blocks: nice prefix"
test_hook "timeout 60 gh workflow run release.yml" 2 "Blocks: timeout prefix"
test_hook "strace gh workflow run release.yml" 2 "Blocks: strace prefix"
test_hook "ltrace gh workflow run release.yml" 2 "Blocks: ltrace prefix"

echo ""
echo "--- More command prefix variations ---"
echo ""

test_hook "sudo gh workflow run release.yml" 2 "Blocks: sudo prefix"
test_hook "sudo -u user gh workflow run release.yml" 2 "Blocks: sudo -u prefix"
test_hook "doas gh workflow run release.yml" 2 "Blocks: doas prefix"
test_hook "sg group -c 'gh workflow run release.yml'" 2 "Blocks: sg prefix"
test_hook "exec gh workflow run release.yml" 2 "Blocks: exec prefix"
test_hook "command gh workflow run release.yml" 2 "Blocks: command prefix"
test_hook "builtin echo x && gh workflow run release.yml" 2 "Blocks: builtin prefix chain"
test_hook "true && gh workflow run release.yml" 2 "Blocks: true && chain"
test_hook "false || gh workflow run release.yml" 2 "Blocks: false || chain"
test_hook ": && gh workflow run release.yml" 2 "Blocks: noop && chain"
test_hook "cd /tmp && gh workflow run release.yml" 2 "Blocks: cd && chain"
test_hook "pushd /tmp && gh workflow run release.yml" 2 "Blocks: pushd && chain"

echo ""
echo "--- gh release create with command prefixes ---"
echo ""

test_hook "export CI=true && gh release create v1.0.0" 2 "Blocks: export + gh release create"
test_hook "CI=true gh release create v1.0.0" 2 "Blocks: env var + gh release create"
test_hook "bash -c 'gh release create v1.0.0'" 2 "Blocks: bash -c + gh release create"
test_hook "sudo gh release create v1.0.0" 2 "Blocks: sudo + gh release create"
test_hook "true && gh release create v1.0.0" 2 "Blocks: true && gh release create"

echo ""
echo "--- Subshell and backgrounding attempts ---"
echo ""

test_hook "(gh workflow run release.yml)" 2 "Blocks: subshell"
test_hook "( gh workflow run release.yml )" 2 "Blocks: subshell with spaces"
test_hook "\$(gh workflow run release.yml)" 2 "Blocks: command substitution"
test_hook "\`gh workflow run release.yml\`" 2 "Blocks: backtick substitution"
test_hook "gh workflow run release.yml &" 2 "Blocks: backgrounded"
test_hook "gh workflow run release.yml & disown" 2 "Blocks: backgrounded and disowned"
test_hook "gh workflow run release.yml | cat" 2 "Blocks: piped to cat"
test_hook "gh workflow run release.yml > /dev/null" 2 "Blocks: redirected to /dev/null"
test_hook "gh workflow run release.yml 2>&1" 2 "Blocks: stderr redirect"
test_hook "gh workflow run release.yml || true" 2 "Blocks: with || true"
test_hook "gh workflow run release.yml && echo done" 2 "Blocks: with && chain"

echo ""
echo "--- Commands that should be ALLOWED ---"
echo ""

test_hook "git status" 0 "Allows: git status"
test_hook "git log" 0 "Allows: git log"
test_hook "git diff" 0 "Allows: git diff"
test_hook "git add ." 0 "Allows: git add"
test_hook "git commit -m test" 0 "Allows: git commit"
test_hook "git push" 0 "Allows: git push"
test_hook "git tag v1.0.0" 0 "Allows: git tag"
test_hook "git checkout main" 0 "Allows: git checkout"

echo ""
echo "--- gh commands that should be ALLOWED ---"
echo ""

test_hook "gh pr create" 0 "Allows: gh pr create"
test_hook "gh pr list" 0 "Allows: gh pr list"
test_hook "gh pr view 123" 0 "Allows: gh pr view"
test_hook "gh pr merge 123" 0 "Allows: gh pr merge"
test_hook "gh issue list" 0 "Allows: gh issue list"
test_hook "gh issue create" 0 "Allows: gh issue create"
test_hook "gh repo view" 0 "Allows: gh repo view"
test_hook "gh repo clone owner/repo" 0 "Allows: gh repo clone"
test_hook "gh auth status" 0 "Allows: gh auth status"
test_hook "gh api user" 0 "Allows: gh api user"
test_hook "gh gist list" 0 "Allows: gh gist list"
test_hook "gh run list" 0 "Allows: gh run list"
test_hook "gh run view 123" 0 "Allows: gh run view"
test_hook "gh run watch 123" 0 "Allows: gh run watch"

echo ""
echo "--- gh workflow commands that should be ALLOWED ---"
echo ""

test_hook "gh workflow list" 0 "Allows: gh workflow list"
test_hook "gh workflow view" 0 "Allows: gh workflow view"
test_hook "gh workflow view release.yml" 0 "Allows: gh workflow view release.yml"
test_hook "gh workflow disable release.yml" 0 "Allows: gh workflow disable"
test_hook "gh workflow enable release.yml" 0 "Allows: gh workflow enable"
test_hook "gh workflow run ci.yml" 0 "Allows: gh workflow run ci.yml"
test_hook "gh workflow run test.yml" 0 "Allows: gh workflow run test.yml"
test_hook "gh workflow run lint.yml" 0 "Allows: gh workflow run lint.yml"
test_hook "gh workflow run build.yml" 0 "Allows: gh workflow run build.yml"
test_hook "gh workflow run deploy.yml" 0 "Allows: gh workflow run deploy.yml"
test_hook "gh workflow run publish.yml" 0 "Allows: gh workflow run publish.yml"

echo ""
echo "--- gh release commands that should be ALLOWED ---"
echo ""

test_hook "gh release list" 0 "Allows: gh release list"
test_hook "gh release view v1.0.0" 0 "Allows: gh release view"
test_hook "gh release delete v1.0.0" 0 "Allows: gh release delete"
test_hook "gh release edit v1.0.0" 0 "Allows: gh release edit"
test_hook "gh release download v1.0.0" 0 "Allows: gh release download"
test_hook "gh release upload v1.0.0 file.zip" 0 "Allows: gh release upload"
test_hook "gh release delete-asset v1.0.0 file.zip" 0 "Allows: gh release delete-asset"

echo ""
echo "--- Bypass mechanism ---"
echo ""

test_hook "gh workflow run release.yml # BYPASS_RELEASE: testing" 0 "Allows: with BYPASS_RELEASE"
test_hook "gh workflow run release.yml -f version=1.0.0 # BYPASS_RELEASE: approved" 0 "Allows: with flags + BYPASS_RELEASE"
test_hook "gh workflow run Release # BYPASS_RELEASE: emergency" 0 "Allows: Release + BYPASS_RELEASE"
test_hook "gh release create v1.0.0 # BYPASS_RELEASE: approved by PM" 0 "Allows: gh release create + BYPASS_RELEASE"
test_hook "export CI=true && gh workflow run release.yml # BYPASS_RELEASE: test" 0 "Allows: prefixed + BYPASS_RELEASE"

echo ""
echo "--- Bypass requires exact keyword ---"
echo ""

test_hook "gh workflow run release.yml # BYPASS_RELEASES: test" 2 "Blocks: BYPASS_RELEASES (wrong keyword)"
test_hook "gh workflow run release.yml # bypass_release: test" 2 "Blocks: lowercase bypass_release"
test_hook "gh workflow run release.yml # BYPASSRELEASE: test" 2 "Blocks: BYPASSRELEASE (no underscore)"
test_hook "gh workflow run release.yml # BYPASS RELEASE: test" 2 "Blocks: BYPASS RELEASE (space)"
test_hook "gh workflow run release.yml # release approved" 2 "Blocks: no bypass keyword"

echo ""
echo "--- JSON parsing edge cases ---"
echo ""

if echo "" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: empty stdin (fail open)"
else
  fail "Allows: empty stdin"
fi

if echo "{}" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: empty JSON object"
else
  fail "Allows: empty JSON object"
fi

if echo "not json" | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: invalid JSON"
else
  fail "Allows: invalid JSON"
fi

if echo '{"tool_input":{}}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: JSON without command field"
else
  fail "Allows: JSON without command field"
fi

if echo '{"tool_input":{"command":""}}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: JSON with empty command"
else
  fail "Allows: JSON with empty command"
fi

if echo '{"tool_input":{"command":null}}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: JSON with null command"
else
  fail "Allows: JSON with null command"
fi

if echo '{"other_field":"value"}' | bash "$HOOK_SCRIPT" >/dev/null 2>&1; then
  pass "Allows: JSON with different structure"
else
  fail "Allows: JSON with different structure"
fi

echo ""
echo "--- Commands that look similar but should NOT match ---"
echo ""

test_hook "echo gh workflow run release.yml" 0 "Allows: echo with command"
test_hook "cat release.yml" 0 "Allows: cat release.yml"
test_hook "vim release.yml" 0 "Allows: vim release.yml"
test_hook "git show release.yml" 0 "Allows: git show release.yml"
test_hook "grep pattern release.yml" 0 "Allows: grep in release.yml"
test_hook "gh run view --log release.yml" 0 "Allows: gh run view with release.yml"
test_hook "git log --oneline release.yml" 0 "Allows: git log release.yml"
test_hook "less .github/workflows/release.yml" 0 "Allows: less release.yml"

echo ""
echo "--- Error message verification ---"
echo ""

test_hook_with_output "gh workflow run release.yml" 2 "BLOCKED" "Error contains: BLOCKED"
test_hook_with_output "gh workflow run release.yml" 2 "human approval" "Error contains: human approval"
test_hook_with_output "gh workflow run release.yml" 2 "BYPASS_RELEASE" "Error contains: BYPASS_RELEASE"
test_hook_with_output "gh workflow run release.yml" 2 "gh workflow run release.yml" "Error contains: command hint"

echo ""
echo "--- Whitespace variations ---"
echo ""

test_hook "gh  workflow  run  release.yml" 2 "Blocks: multiple spaces"
test_hook $'gh\tworkflow\trun\trelease.yml' 2 "Blocks: tabs instead of spaces"
test_hook "  gh workflow run release.yml" 2 "Blocks: leading spaces"
test_hook "gh workflow run release.yml  " 2 "Blocks: trailing spaces"
test_hook "gh   release   create   v1.0.0" 2 "Blocks: gh release create with extra spaces"

echo ""
echo "--- Case sensitivity ---"
echo ""

test_hook "GH workflow run release.yml" 0 "Allows: uppercase GH (not gh)"
test_hook "gh WORKFLOW run release.yml" 0 "Allows: uppercase WORKFLOW"
test_hook "gh workflow RUN release.yml" 0 "Allows: uppercase RUN"
test_hook "gh workflow run RELEASE.yml" 0 "Allows: uppercase RELEASE.yml"
test_hook "gh workflow run Release.yml" 0 "Allows: mixed case Release.yml"
test_hook "gh RELEASE create v1.0.0" 0 "Allows: uppercase RELEASE"
test_hook "GH RELEASE CREATE v1.0.0" 0 "Allows: all uppercase"

echo ""
echo "--- Complex real-world commands ---"
echo ""

test_hook "export CI=true DEBIAN_FRONTEND=noninteractive GIT_TERMINAL_PROMPT=0 && gh workflow run release.yml -f version=1.0.0" 2 "Blocks: complex export chain"
test_hook "cd /tmp && export PATH=/usr/bin:\$PATH && gh workflow run release.yml" 2 "Blocks: cd + export + command"
test_hook "source ~/.bashrc && gh workflow run release.yml" 2 "Blocks: source + command"
test_hook ". ~/.profile && gh workflow run release.yml" 2 "Blocks: dot source + command"
test_hook "set -e && gh workflow run release.yml" 2 "Blocks: set -e + command"
test_hook "trap 'echo done' EXIT && gh workflow run release.yml" 2 "Blocks: trap + command"

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
