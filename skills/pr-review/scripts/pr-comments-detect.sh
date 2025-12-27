#!/bin/bash
# Detect and validate PR number for current workspace
# Usage: ./pr-comments-detect.sh [--no-validate]
#   --no-validate: Skip validation that detected PR matches current commit SHA

set -euo pipefail

# Initialize script using utility function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "${SCRIPT_DIR}/lib/pr-comments-utils.sh" || ! setup_pr_comments_script; then
  exit 1
fi

# Parse arguments
VALIDATE=true
if [ "${1:-}" = "--no-validate" ]; then
  VALIDATE=false
fi

echo "🔍 Detecting PR number..."
echo ""

# Detect PR number
PR_NUMBER=$(detect_pr_number)

if [ -z "$PR_NUMBER" ]; then
  log_error "Could not detect PR number automatically"
  echo ""
  echo "Try one of these methods:"
  echo "  1. Run 'bun run pr:comments <PR_NUMBER>' first to create a metadata file"
  echo "  2. Use 'gh pr view' to see if GitHub CLI can detect the PR"
  echo "  3. Manually specify the PR number when running commands"
  exit 1
fi

echo "✅ Detected PR: #${PR_NUMBER}"
echo ""

# Validate if requested
if [ "$VALIDATE" = "true" ]; then
  echo "🔍 Validating PR matches current commit..."
  
  if validate_pr_matches_commit "$PR_NUMBER"; then
    CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
    echo "✅ Validation passed: PR #${PR_NUMBER} matches current commit (${CURRENT_SHA:0:8}...)"
    echo ""
    echo "PR Number: ${PR_NUMBER}"
    exit 0
  else
    CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
    PR_HEAD_SHA=$(get_pr_commit_sha "$PR_NUMBER" 2>/dev/null || echo "")
    log_error "Validation failed: PR #${PR_NUMBER} doesn't match current commit"
    echo ""
    if [ -n "$CURRENT_SHA" ]; then
      echo "Current commit: ${CURRENT_SHA:0:8}..."
    fi
    if [ -n "$PR_HEAD_SHA" ]; then
      echo "PR head commit: ${PR_HEAD_SHA:0:8}..."
    fi
    echo ""
    echo "⚠️  Warning: The detected PR may not correspond to your current workspace state."
    echo "   This can happen if:"
    echo "     - You're on a different commit than the PR head"
    echo "     - Multiple PRs exist and detection picked the wrong one"
    echo "     - You're working with GitButler and commits have changed"
    echo ""
    echo "❌ PR number NOT validated - do not use this PR number"
    echo ""
    echo "To proceed anyway (skip validation), use: bun run pr:comments:detect --no-validate"
    exit 1
  fi
else
  echo "⚠️  Validation skipped (--no-validate flag used)"
  echo ""
  echo "PR Number: ${PR_NUMBER}"
  exit 0
fi

