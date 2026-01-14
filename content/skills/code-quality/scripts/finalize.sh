#!/bin/bash
# Finalize script - runs typecheck, lint, format check/write, and markdown check
# Shows full error messages with line numbers, exits with error code if any check fails
#
# Usage:
#   bash scripts/finalize.sh [ci|agent]
#   - ci:    Runs format:check (read-only checks) - for CI/CD pipelines
#   - agent: Runs format:write (auto-fixes formatting) - for agent sessions
#   Default: agent mode

set -euo pipefail

MODE="${1:-agent}"

# Validate mode
if [ "$MODE" != "ci" ] && [ "$MODE" != "agent" ]; then
  echo "❌ Error: Invalid mode '$MODE'"
  echo "Usage: $0 [ci|agent]"
  echo "  ci:    Runs format:check (read-only checks)"
  echo "  agent:  Runs format:write (auto-fixes formatting)"
  exit 1
fi

ERRORS=0

# Create temporary directory for parallel check outputs
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "🚀 Running checks in parallel..."
echo ""

# Run typecheck in background
(
  bun run typecheck > "$TMPDIR/typecheck.out" 2>&1
  echo $? > "$TMPDIR/typecheck.exit"
) &
TYPECHECK_PID=$!

# Run lint in background
(
  bun run lint > "$TMPDIR/lint.out" 2>&1
  echo $? > "$TMPDIR/lint.exit"
) &
LINT_PID=$!

# Run format check/write in background
if [ "$MODE" = "ci" ]; then
  (
    bun run format:check > "$TMPDIR/format.out" 2>&1
    echo $? > "$TMPDIR/format.exit"
  ) &
  FORMAT_PID=$!
else
  (
    bun run format:write > "$TMPDIR/format.out" 2>&1
    echo $? > "$TMPDIR/format.exit"
  ) &
  FORMAT_PID=$!
fi

# Run markdown check in background
(
  MARKDOWN_FILES=$(find . -type f -name "*.md" \
    -not -path "./node_modules/*" \
    -not -path "./.next/*" \
    -not -path "./.git/*" \
    -not -path "./dist/*" \
    -not -path "./build/*" \
    -not -path "./.ada/*" \
    -not -path "./.cursor/*" \
    2>/dev/null | sort || echo "")
  
  if [ -z "$MARKDOWN_FILES" ]; then
    echo "✅ No markdown files found" > "$TMPDIR/markdown.out"
    echo 0 > "$TMPDIR/markdown.exit"
  else
    MARKDOWN_COUNT=$(echo "$MARKDOWN_FILES" | wc -l | xargs)
    echo "Found $MARKDOWN_COUNT markdown file(s)" > "$TMPDIR/markdown.out"
    
    # Check for common markdown issues
    MARKDOWN_ISSUES=0
    
    while IFS= read -r file; do
      if [ -z "$file" ]; then
        continue
      fi
      
      # Check for trailing whitespace
      if grep -l '[[:space:]]$' "$file" >/dev/null 2>&1; then
        echo "  ⚠️  $file: Contains trailing whitespace" >> "$TMPDIR/markdown.out"
        MARKDOWN_ISSUES=$((MARKDOWN_ISSUES + 1))
      fi
      
      # Check for missing newline at end of file
      if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -c)" -gt 0 ] && [ "$(tail -c 1 "$file")" != "$(printf '\n')" ]; then
        echo "  ⚠️  $file: Missing newline at end of file" >> "$TMPDIR/markdown.out"
        MARKDOWN_ISSUES=$((MARKDOWN_ISSUES + 1))
      fi
    done <<< "$MARKDOWN_FILES"
    
    if [ $MARKDOWN_ISSUES -eq 0 ]; then
      echo "✅ No markdown issues found" >> "$TMPDIR/markdown.out"
      echo 0 > "$TMPDIR/markdown.exit"
    else
      echo "❌ Found $MARKDOWN_ISSUES markdown issue(s)" >> "$TMPDIR/markdown.out"
      echo 1 > "$TMPDIR/markdown.exit"
    fi
  fi
) &
MARKDOWN_PID=$!

# Wait for all background processes to complete
wait $TYPECHECK_PID $LINT_PID $FORMAT_PID $MARKDOWN_PID

# Display results in order
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Check Results:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Typecheck results
echo "🔍 Typecheck:"
TYPECHECK_EXIT=$(cat "$TMPDIR/typecheck.exit" 2>/dev/null || echo "1")
if [ "$TYPECHECK_EXIT" -ne 0 ]; then
  echo "❌ Typecheck failed:"
  cat "$TMPDIR/typecheck.out"
  ERRORS=1
else
  echo "✅ Typecheck passed"
fi

echo ""

# Lint results
echo "🔍 Lint:"
LINT_EXIT=$(cat "$TMPDIR/lint.exit" 2>/dev/null || echo "1")
if [ "$LINT_EXIT" -ne 0 ]; then
  echo "❌ Lint failed:"
  cat "$TMPDIR/lint.out"
  ERRORS=1
else
  echo "✅ Lint passed"
fi

echo ""

# Format results
if [ "$MODE" = "ci" ]; then
  echo "🔍 Format Check (CI mode):"
else
  echo "🔧 Format Write (agent mode):"
fi
FORMAT_EXIT=$(cat "$TMPDIR/format.exit" 2>/dev/null || echo "1")
if [ "$FORMAT_EXIT" -ne 0 ]; then
  if [ "$MODE" = "ci" ]; then
    echo "❌ Format check failed:"
  else
    echo "❌ Format write failed:"
  fi
  cat "$TMPDIR/format.out"
  ERRORS=1
else
  if [ "$MODE" = "ci" ]; then
    echo "✅ Format check passed"
  else
    echo "✅ Format write completed"
  fi
fi

echo ""

# Markdown results
echo "📝 Markdown Check:"
MARKDOWN_EXIT=$(cat "$TMPDIR/markdown.exit" 2>/dev/null || echo "0")
cat "$TMPDIR/markdown.out"
if [ "$MARKDOWN_EXIT" -ne 0 ]; then
  ERRORS=1
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "✅ All checks passed!"
  exit 0
else
  echo "❌ Some checks failed. Please fix the errors above."
  exit 1
fi
