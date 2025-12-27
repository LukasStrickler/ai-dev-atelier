#!/bin/bash
# Run all research extraction tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Running All Research Extraction Tests"
echo "=========================================="
echo ""

TESTS=(
  "test-direct-answer.md.sh"
  "test-subdirectory-answer.md.sh"
  "test-patch-extraction.sh"
  "test-ndjson-synthesis.sh"
  "test-placeholder-creation.sh"
  "test-work-mode-merge.sh"
  "test-research-mode-no-merge.sh"
)

PASSED=0
FAILED=0
WARNINGS=0

for test in "${TESTS[@]}"; do
  if [ -f "$test" ]; then
    echo ""
    echo "----------------------------------------"
    if bash "$test"; then
      PASSED=$((PASSED + 1))
    else
      EXIT_CODE=$?
      if [ $EXIT_CODE -eq 1 ]; then
        FAILED=$((FAILED + 1))
      else
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
    echo "----------------------------------------"
    sleep 2  # Brief pause between tests
  else
    echo "⚠️  Test file not found: $test"
    WARNINGS=$((WARNINGS + 1))
  fi
done

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo "Warnings: $WARNINGS"
echo "Total:   $((PASSED + FAILED + WARNINGS))"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "✅ All critical tests passed!"
  exit 0
else
  echo "❌ Some tests failed"
  exit 1
fi

