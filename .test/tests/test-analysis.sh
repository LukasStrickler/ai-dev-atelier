#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYSIS_DIR="$SCRIPT_DIR/../analysis"
FIXTURES_DIR="$ANALYSIS_DIR/fixtures"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
  ((TESTS_PASSED++)) || true
  ((TESTS_RUN++)) || true
  printf "  ✓ %s\n" "$1"
}

fail() {
  ((TESTS_FAILED++)) || true
  ((TESTS_RUN++)) || true
  printf "  ✗ %s\n" "$1"
  if [[ -n "${2:-}" ]]; then
    printf "    Expected: %s\n" "$2"
    printf "    Got:      %s\n" "$3"
  fi
}

assert_contains() {
  local output="$1"
  local expected="$2"
  local test_name="$3"
  
  if echo "$output" | grep -qF "$expected"; then
    pass "$test_name"
  else
    fail "$test_name" "contains '$expected'" "not found"
  fi
}

assert_matches() {
  local output="$1"
  local pattern="$2"
  local test_name="$3"
  
  if echo "$output" | grep -qE "$pattern"; then
    pass "$test_name"
  else
    fail "$test_name" "matches '$pattern'" "no match"
  fi
}

echo "=== Analysis Script Tests ==="
echo ""

echo "--- analyze-skill-usage.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-skill-usage.sh" "$FIXTURES_DIR/sample-telemetry.jsonl" 2>&1)
assert_contains "$OUTPUT" "Total events: 50" "counts total events"
assert_contains "$OUTPUT" "Unique skills: 10" "counts unique skills"
assert_contains "$OUTPUT" "code-quality" "shows code-quality skill"
assert_contains "$OUTPUT" "Skill loads:" "shows load breakdown"
assert_contains "$OUTPUT" "Script executions:" "shows script breakdown"
assert_contains "$OUTPUT" "finalize.sh" "shows script names"

if "$ANALYSIS_DIR/analyze-skill-usage.sh" "$FIXTURES_DIR/minimal-telemetry.jsonl" >/dev/null 2>&1; then
  pass "handles minimal input"
else
  fail "handles minimal input"
fi

if ! "$ANALYSIS_DIR/analyze-skill-usage.sh" "/nonexistent/file.jsonl" >/dev/null 2>&1; then
  pass "fails on missing file"
else
  fail "fails on missing file"
fi
echo ""

echo "--- analyze-sessions.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-sessions.sh" "$FIXTURES_DIR/sample-telemetry.jsonl" 2>&1)
assert_contains "$OUTPUT" "Total sessions: 15" "counts total sessions"
assert_contains "$OUTPUT" "Events Per Session" "shows per-session stats"
assert_contains "$OUTPUT" "Single-skill sessions:" "shows single-skill count"
assert_contains "$OUTPUT" "Multi-skill sessions:" "shows multi-skill count"
echo ""

echo "--- analyze-cooccurrence.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-cooccurrence.sh" "$FIXTURES_DIR/cooccurrence-test.jsonl" 2>&1)
assert_contains "$OUTPUT" "Most Common Skill Pairs" "shows skill pairs section"
assert_contains "$OUTPUT" "Skill Sequences" "shows sequences section"
assert_contains "$OUTPUT" "code-quality + git-commit" "finds expected pair"
echo ""

echo "--- analyze-trends.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-trends.sh" "$FIXTURES_DIR/sample-telemetry.jsonl" 2>&1)
assert_contains "$OUTPUT" "Date range:" "shows date range"
assert_contains "$OUTPUT" "2026-01-06 to 2026-01-13" "shows correct dates"
assert_contains "$OUTPUT" "Daily Usage" "shows daily section"
echo ""

echo "--- analyze-versions.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-versions.sh" "$FIXTURES_DIR/version-tracking.jsonl" 2>&1)
assert_contains "$OUTPUT" "Events with version:" "shows version counts"
assert_contains "$OUTPUT" "Events without version:" "shows missing version count"
assert_contains "$OUTPUT" "Version Distribution" "shows distribution section"
echo ""

echo "--- analyze-repos.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-repos.sh" "$FIXTURES_DIR/sample-telemetry.jsonl" 2>&1)
assert_contains "$OUTPUT" "Total repositories: 4" "counts repositories"
assert_contains "$OUTPUT" "my-webapp" "shows my-webapp repo"
assert_contains "$OUTPUT" "api-service" "shows api-service repo"
assert_contains "$OUTPUT" "Repository Skill Diversity" "shows diversity section"
echo ""

echo "--- analyze-retention.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-retention.sh" "$FIXTURES_DIR/sample-telemetry.jsonl" 2>&1)
assert_contains "$OUTPUT" "Total sessions: 15" "shows session count"
assert_contains "$OUTPUT" "Skill Reach" "shows reach section"
assert_contains "$OUTPUT" "Skill Stickiness" "shows stickiness section"
echo ""

echo "--- analyze-all.sh ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-all.sh" "$FIXTURES_DIR/sample-telemetry.jsonl" 2>&1)
assert_contains "$OUTPUT" "SKILL TELEMETRY ANALYSIS REPORT" "shows report header"
assert_contains "$OUTPUT" "Skill Usage Analysis" "includes usage analysis"
assert_contains "$OUTPUT" "Session Analysis" "includes session analysis"
assert_contains "$OUTPUT" "Report complete" "shows completion"

OUTPUT=$("$ANALYSIS_DIR/analyze-all.sh" "$FIXTURES_DIR/sample-telemetry.jsonl" --json 2>&1)
assert_contains "$OUTPUT" '"total_events": 50' "JSON mode: shows total events"
assert_contains "$OUTPUT" '"unique_skills": 10' "JSON mode: shows unique skills"
echo ""

echo "--- Edge Cases ---"
OUTPUT=$("$ANALYSIS_DIR/analyze-skill-usage.sh" "$FIXTURES_DIR/minimal-telemetry.jsonl" 2>&1)
assert_contains "$OUTPUT" "Total events: 1" "minimal: counts 1 event"
assert_contains "$OUTPUT" "Unique skills: 1" "minimal: counts 1 skill"
echo ""

echo "=== Test Summary ==="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
  exit 1
fi
